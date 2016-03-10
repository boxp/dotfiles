import System.IO
import XMonad
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.ManageDocks
import XMonad.Util.Run(spawnPipe)
import XMonad.Hooks.SetWMName
import XMonad.Hooks.EwmhDesktops

main = do
    xmproc <- spawnPipe "xmobar"
    xmonad $ defaultConfig
        { manageHook = manageDocks <+> manageHook defaultConfig
        , layoutHook = avoidStruts $ layoutHook defaultConfig
        , logHook = dynamicLogWithPP $ xmobarPP
                        { ppOutput = hPutStrLn xmproc
                        , ppTitle = xmobarColor "green" "" . shorten 50
                        }
        , terminal           = "sakura"
        , modMask            = mod4Mask
        , handleEventHook    = fullscreenEventHook
        , borderWidth        = 3
        , normalBorderColor  = "#333333"
        , focusedBorderColor = "#cb4b16"
        , startupHook = setWMName "LG3D"
        }
