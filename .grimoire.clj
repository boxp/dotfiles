; Grimoire settings
; Created by BOXP<http://archbox.dip.jp/>

(use 'clojure.repl)

; theme settings
; solarized_dark
(reset! theme "solarized_dark")
; set tweet text size
(reset! tweets-size 13)

; キーマップを追加
; キー：["キーコード" コントロールキー? シフトキー?]
; バリュー：引数一つの関数(引数はKeyEvent)
(dosync
  (alter key-maps merge 
    {["I" false false] 
     (fn [_]
       (.requestFocus (get-node "#form")))}))

; リプ爆用関数
(defn little-region
  "槍を持った人形達が，標的に向かって突進して行く
   (複数のアカウントから特定のツイート・ユーザーに対して
   同じリプライを送る)
  
   例1：(little-region @twitters 'marisa' 'hello')
   全てのアカウントから@marisaに向けてhelloと呟く
  
   例2：(little-region (-> @twitters (dissoc :syanhai1))
                      'marisa'
                      'ごきげんいかが')
   syanhai1以外の全てのアカウントから@marisaに対して
   ごきげんいかがと呟く"
  [twitters username txt]
  (-> twitters 
      vals 
      (#(doall 
         (pmap 
           (fn [a] (.updateStatus a 
                     (str "@" username " " txt)))
            %)))))

(defn dolls-war
  "人形たちの戦争．次々と生み出される人形の，死を恐れぬ攻撃が敵を追い詰める．
   (複数のアカウントから特定のユーザーの複数のツイートを全てお気に入りに登録する)"
  [twitters user-name]
  (let [user-id (-> twitters vals first (.showUser user-name) .getId)
        user-timeline (-> twitters vals first (.getUserTimeline user-id))]
    (doall
      (for [x (vals twitters)
            y user-timeline]
        (try
          (.createFavorite x (.getId y))
          (catch Exception e nil))))))

(defn eval-twi
  [cls]
  (let [cls-str (str cls)
        res (try
              (eval cls)
              (catch Exception e (. e getStackTrace)))]
    (post (str cls-str " => " res))))
