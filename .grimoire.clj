; Grimoire settings
; Created by BOXP<http://archbox.dip.jp/>

; theme settings
; solarized_dark
(set-theme! "solarized_dark")
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
