#!/usr/bin/env bb

(ns generate-image
  (:require [babashka.http-client :as http]
            [cheshire.core :as json]
            [clojure.tools.cli :refer [parse-opts]]
            [clojure.java.io :as io]
            [clojure.string :as str])
  (:import [java.util Base64]
           [java.time.format DateTimeFormatter]
           [java.time LocalDateTime]))

(def cli-options
  [["-a" "--aspect-ratio RATIO" "アスペクト比"
    :default "1:1"]
   ["-s" "--size SIZE" "画像サイズ 1K/2K/4K"
    :default "2K"]
   ["-o" "--output PATH" "出力ファイルパス"]
   ["-i" "--image PATH" "入力画像パス（複数指定可）"
    :multi true
    :default []
    :update-fn conj]
   ["-h" "--help" "ヘルプ表示"]])

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
      {:mimeType mime :data b64})))

(defn default-output-path [mime-type]
  (let [ext (ext-from-mime mime-type)
        ts  (.format (LocalDateTime/now) (DateTimeFormatter/ofPattern "yyyyMMdd-HHmmss"))]
    (str "./gemini-" ts "." ext)))

(defn build-request-body [prompt images aspect-ratio size]
  (let [text-part {:text prompt}
        image-parts (mapv (fn [img-data] {:inlineData img-data}) images)
        parts (into [text-part] image-parts)]
    {:contents [{:parts parts}]
     :generationConfig {:responseModalities ["TEXT" "IMAGE"]
                        :imageConfig {:aspectRatio aspect-ratio
                                      :imageSize size}}}))

(defn call-api [api-key body]
  (let [url "https://generativelanguage.googleapis.com/v1beta/models/gemini-3-pro-image-preview:generateContent"
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
  (let [{:keys [options arguments summary errors]} (parse-opts args cli-options)]
    (when errors
      (doseq [e errors] (binding [*out* *err*] (println e)))
      (System/exit 1))
    (when (:help options)
      (println "Usage: bb generate-image.bb [options] <prompt>\n")
      (println summary)
      (System/exit 0))
    (when (empty? arguments)
      (println "Usage: bb generate-image.bb [options] <prompt>\n")
      (println summary)
      (die "\nError: Prompt is required."))
    (let [api-key      (validate-env)
          prompt       (str/join " " arguments)
          images       (mapv load-image (:image options))
          aspect-ratio (:aspect-ratio options)
          size         (:size options)
          output       (:output options)
          body         (build-request-body prompt images aspect-ratio size)
          response     (call-api api-key body)
          inline-data  (extract-image response)
          saved-path   (decode-and-save inline-data output)]
      (println saved-path))))

(-main *command-line-args*)
