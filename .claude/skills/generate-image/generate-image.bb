#!/usr/bin/env bb
(ns generate-image
  (:require [clojure.java.io :as io] [clojure.string :as str]
            [clojure.tools.cli :refer [parse-opts]] [cheshire.core :as json])
  (:import [java.security MessageDigest] [java.time Instant]))

(def opts [["-i" "--image PATH" "参照画像（複数可）" :multi true :default [] :update-fn conj]
           ["-o" "--output PATH" "PNG出力先"] ["-a" "--aspect-ratio RATIO" "比率"]
           ["-s" "--size SIZE" "サイズ"] ["-m" "--model MODEL" "非対応"]
           ["-S" "--seed SEED" "非対応"] [nil "--dry-run" "実行内容を表示"]
           ["-h" "--help" "ヘルプ"]])
(defn die [s] (throw (ex-info s {})))
(defn run [args capture?]
  (let [p (ProcessBuilder. ^java.util.List args) env (.environment p)]
    (doseq [k (keys (into {} env)) :when (or (str/starts-with? k "OPENAI_") (str/starts-with? k "AZURE_OPENAI_") (= k "CODEX_API_KEY"))] (.remove env k))
    (.redirectErrorStream p true)
    (if capture?
      (let [proc (.start p) _ (.close (.getOutputStream proc)) output (slurp (.getInputStream proc)) code (.waitFor proc)] {:code code :output output})
      (do (.inheritIO p) (let [proc (.start p)] {:code (.waitFor proc)})))))
(defn sha [f]
  (let [digest (MessageDigest/getInstance "SHA-256")]
    (with-open [in (io/input-stream f)] (let [buf (byte-array 8192)] (loop [] (let [n (.read in buf)] (when (pos? n) (.update digest buf 0 n) (recur))))))
    (apply str (map #(format "%02x" (bit-and 255 %)) (.digest digest)))))
(defn main []
  (let [{:keys [options arguments errors summary]} (parse-opts *command-line-args* opts)]
    (when errors (die (str/join "; " errors)))
    (when (:help options) (println (str "Usage: generate-image.bb [options] <prompt>\n" summary)) (System/exit 0))
    (when (:model options) (die "-m/--model is unsupported; Gemini models cannot be used."))
    (when (:seed options) (die "-S/--seed is unsupported."))
    (when (empty? arguments) (die "prompt is required"))
    (let [prompt (str/join " " arguments)
          images (mapv #(.getCanonicalPath (io/file %)) (:image options))
          output (.getCanonicalFile (io/file (or (:output options) (str "image-" (System/currentTimeMillis) ".png"))))
          dir (.getParentFile output)
          instruction (str "Use the built-in image_gen tool exactly once to generate one image. Never call any other image API or retry. Do not run shell commands or copy files; the caller will retrieve the image from this session. Do not use a pre-existing image. User prompt:\n" prompt
                           (when (:aspect-ratio options) (str "\nRequested aspect ratio: " (:aspect-ratio options)))
                           (when (:size options) (str "\nRequested size: " (:size options))))]
      (doseq [p images] (when-not (.isFile (io/file p)) (die (str "input image not found: " p))))
      (when-not (.isDirectory dir) (die (str "output directory does not exist: " dir)))
      (when-not (str/ends-with? (str/lower-case (.getName output)) ".png") (die "output must end in .png"))
      (let [base ["codex" "exec" "--sandbox" "workspace-write" "--skip-git-repo-check" "--ephemeral" "--ignore-user-config" "--json"]
            image-args (vec (mapcat #(vector "-i" %) images))]
        (when (:dry-run options)
          (println (pr-str (into (into base ["-C" (str dir "/<temporary-workspace>")]) (concat image-args ["--" instruction]))))
          (System/exit 0))
        (when-not (some #(and (.isFile (io/file % "codex")) (.canExecute (io/file % "codex"))) (str/split (or (System/getenv "PATH") "") #":")) (die "codex executable not found"))
        (let [login (run ["codex" "login" "status"] true)]
          (when-not (and (zero? (:code login)) (re-find #"(?i)logged in using chatgpt" (:output login))) (die "ChatGPT login required (API key login is not supported)")))
        (let [features (run ["codex" "features" "list"] true)]
          (when-not (and (zero? (:code features)) (re-find #"(?m)^image_generation\s+\S+\s+true\s*$" (:output features))) (die "codex image_generation feature is not enabled")))
        (let [version (str/trim (:output (run ["codex" "--version"] true)))
              temp (.toFile (java.nio.file.Files/createTempDirectory (.toPath dir) ".image-gen-" (make-array java.nio.file.attribute.FileAttribute 0)))
              result (io/file temp "result.png") start (System/nanoTime)]
          (try
            (let [response (run (into (into base ["-C" (.getPath temp)]) (concat image-args ["--" instruction])) true)
                  elapsed (/ (- (System/nanoTime) start) 1e9)]
              (when-not (zero? (:code response)) (die (str "codex exec failed (exit " (:code response) "); no retry")))
              (when-not (.isFile result)
                (let [events (keep (fn [line] (try (json/parse-string line true) (catch Exception _ nil))) (str/split-lines (:output response)))
                      thread-id (:thread_id (first (filter #(= "thread.started" (:type %)) events)))
                      home (or (System/getenv "CODEX_HOME") (str (System/getenv "HOME") "/.codex"))
                      thread-dir (when (and thread-id (re-matches #"[0-9a-fA-F-]+" thread-id)) (io/file home "generated_images" thread-id))
                      pngs (if (and thread-dir (.isDirectory thread-dir)) (filter #(and (.isFile %) (str/ends-with? (str/lower-case (.getName %)) ".png")) (file-seq thread-dir)) [])]
                  (when-not (= 1 (count pngs)) (die "cannot identify exactly one generated PNG for this session"))
                  (io/copy (first pngs) result)))
              (let [signature (with-open [in (io/input-stream result)] (vec (take 8 (.readAllBytes in))))
                    info (run ["python3" "-c" "import sys,struct,zlib
p=open(sys.argv[1],'rb').read(); assert p[:8]==b'\\x89PNG\\r\\n\\x1a\\n'
o=8; data=b''; end=False
while o < len(p):
 n=struct.unpack('>I',p[o:o+4])[0]; t=p[o+4:o+8]; v=p[o+8:o+8+n]; c=p[o+8+n:o+12+n]; assert len(c)==4 and zlib.crc32(t+v)==struct.unpack('>I',c)[0]; o+=12+n
 if t==b'IDAT': data+=v
 if t==b'IEND': end=True; break
assert end and o==len(p) and len(zlib.decompress(data))>0" (.getPath result)] true)
                    bytes (with-open [in (io/input-stream result)] (.readNBytes in 24))
                    dimension (fn [offset] (reduce (fn [n b] (+ (* n 256) (bit-and 255 b))) 0 (take 4 (drop offset bytes))))
                    width (dimension 16) height (dimension 20)]
                (when-not (and (= signature [-119 80 78 71 13 10 26 10]) (zero? (:code info)) (pos? width) (pos? height)) (die "output is not a valid PNG"))
                (java.nio.file.Files/move (.toPath result) (.toPath output) (into-array java.nio.file.CopyOption [java.nio.file.StandardCopyOption/REPLACE_EXISTING]))
                (spit (str output ".json") (json/generate-string {:timestamp (str (Instant/now)) :route "codex-native-image_gen" :codex_version version :prompt prompt :input_images (mapv (fn [p] {:path p :sha256 (sha p)}) images) :output_sha256 (sha output) :width width :height height :codex_exec_exit_code (:code response) :elapsed_seconds elapsed :model "unknown"} {:pretty true}))
                (println (.getPath output))))
            (finally (doseq [f (reverse (file-seq temp))] (.delete f)))))))))
(try (main) (catch Exception e (binding [*out* *err*] (println (str "Error: " (.getMessage e)))) (System/exit 1)))
