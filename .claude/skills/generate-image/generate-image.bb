#!/usr/bin/env bb

(ns generate-image
  (:require [babashka.http-client :as http]
            [cheshire.core :as json]
            [babashka.cli :as cli]
            [clojure.java.io :as io]
            [clojure.string :as str])
  (:import [java.util Base64]
           [java.time.format DateTimeFormatter]
           [java.time LocalDateTime]))

(def usage-text
  "Usage: bb generate-image.bb [options] <prompt>

Options:
  -a, --aspect-ratio RATIO  アスペクト比 (default: 1:1)
  -s, --size SIZE           画像サイズ 1K/2K/4K (default: 2K)
  -o, --output PATH         出力ファイルパス (default: ./gemini-<timestamp>.<ext>)
  -i, --image PATH          入力画像パス（複数指定可）
  -h, --help                ヘルプ表示")

(def cli-spec
  {:spec
   {:aspect-ratio {:alias :a :default "1:1" :desc "アスペクト比"}
    :size         {:alias :s :default "2K" :desc "画像サイズ"}
    :output       {:alias :o :desc "出力ファイルパス"}
    :image        {:alias :i :coerce [] :desc "入力画像パス"}
    :help         {:alias :h :coerce :boolean :desc "ヘルプ表示"}}})

(defn die [msg]
  (binding [*out* *err*]
    (println msg))
  (System/exit 1))

(defn validate-env []
  (let [key (System/getenv "GEMINI_API_KEY")]
    (when (str/blank? key)
      (die "Error: GEMINI_API_KEY environment variable is not set."))
    key))

(defn mime-type-from-ext [path]
  (let [ext (-> path str/lower-case (str/split #"\.") last)]
    (case ext
      "png"  "image/png"
      "jpg"  "image/jpeg"
      "jpeg" "image/jpeg"
      "webp" "image/webp"
      "gif"  "image/gif"
      (die (str "Error: Unsupported image format: ." ext)))))

(defn ext-from-mime [mime-type]
  (case mime-type
    "image/png"  "png"
    "image/jpeg" "jpg"
    "image/webp" "webp"
    "image/gif"  "gif"
    "png"))

(defn load-image [path]
  (let [f (io/file path)]
    (when-not (.exists f)
      (die (str "Error: Image file not found: " path)))
    (let [bytes (-> f io/input-stream .readAllBytes)
          b64   (.encodeToString (Base64/getEncoder) bytes)
          mime  (mime-type-from-ext path)]
      {:mime_type mime :data b64})))

(defn default-output-path [mime-type]
  (let [ext (ext-from-mime mime-type)
        ts  (.format (LocalDateTime/now) (DateTimeFormatter/ofPattern "yyyyMMdd-HHmmss"))]
    (str "./gemini-" ts "." ext)))

(defn build-request-body [prompt images aspect-ratio size]
  (let [text-part {:text prompt}
        image-parts (mapv (fn [img-data] {:inline_data img-data}) images)
        parts (into [text-part] image-parts)]
    {:contents [{:parts parts}]
     :generationConfig {:responseModalities ["TEXT" "IMAGE"]
                        :imageConfig {:aspectRatio aspect-ratio
                                      :imageSize size}}}))

(defn call-api [api-key body]
  (let [url (str "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent")
        resp (try
               (http/post url
                          {:headers {"x-goog-api-key" api-key
                                     "Content-Type" "application/json"}
                           :body (json/generate-string body)})
               (catch Exception e
                 (die (str "Error: API request failed: " (.getMessage e)))))]
    (when (not= 200 (:status resp))
      (die (str "Error: API returned status " (:status resp) "\n" (:body resp))))
    (json/parse-string (:body resp) true)))

(defn extract-image [response]
  (let [parts (get-in response [:candidates 0 :content :parts])]
    (when-not parts
      (die "Error: No content in API response."))
    (let [image-part (first (filter :inlineData parts))]
      (when-not image-part
        (die "Error: No image data in API response. The model returned text only."))
      (:inlineData image-part))))

(defn decode-and-save [inline-data output-path]
  (let [b64  (:data inline-data)
        mime (:mimeType inline-data)
        path (or output-path (default-output-path mime))
        bytes (.decode (Base64/getDecoder) ^String b64)]
    (io/copy bytes (io/file path))
    path))

(defn -main [args]
  (let [{:keys [args opts]} (cli/parse-args args cli-spec)]
    (when (:help opts)
      (println usage-text)
      (System/exit 0))
    (when (empty? args)
      (println usage-text)
      (die "\nError: Prompt is required."))
    (let [api-key      (validate-env)
          prompt       (str/join " " args)
          images       (mapv load-image (or (:image opts) []))
          aspect-ratio (or (:aspect-ratio opts) "1:1")
          size         (or (:size opts) "2K")
          output       (:output opts)
          body         (build-request-body prompt images aspect-ratio size)
          response     (call-api api-key body)
          inline-data  (extract-image response)
          saved-path   (decode-and-save inline-data output)]
      (println saved-path))))

(-main *command-line-args*)
