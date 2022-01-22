import System.IO
import XMonad
import XMonad.Hooks.DynamicLog
import XMonad.Hooks.ManageDocks
import XMonad.Util.Run(spawnPipe)
import XMonad.Hooks.SetWMName
import XMonad.Hooks.EwmhDesktops
import XMonad.Layout.ResizableTile
import XMonad.Layout.Spacing
import XMonad.Layout.Simplest
import XMonad.Layout.ToggleLayouts
import XMonad.Layout.NoBorders         -- In Full mode, border is no use

main = do
    xmproc <- spawnPipe "xmobar"
    xmonad $ defaultConfig
        { manageHook = manageDocks <+> manageHook defaultConfig
        , layoutHook = avoidStruts $ toggleLayouts (noBorders Full) $ myLayout
        , logHook = dynamicLogWithPP $ xmobarPP
                        { ppOutput = hPutStrLn xmproc
                        , ppTitle = xmobarColor "green" "" . shorten 50
                        }
        , terminal           = "alacritty"
        , modMask            = mod4Mask
        , handleEventHook    = fullscreenEventHook
        -- , borderWidth        = 3
        , normalBorderColor  = "#333333"
        , focusedBorderColor = "#cb4b16"
        , startupHook = setWMName "LG3D"
        }

myLayout = (spacing 18 $ ResizableTall 1 (3/100) (3/5) [])
            ||| Simplest
