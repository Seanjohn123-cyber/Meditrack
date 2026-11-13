@echo off
setlocal enabledelayedexpansion

echo ===================================================
echo   MediTrack Test Suite Runner (Windows)
echo ===================================================

if not exist sim\build mkdir sim\build
if not exist pictures mkdir pictures

set FAILED=0
set TOTAL=0

for %%f in (tb\unit\tb_*.v) do (
    set /a TOTAL+=1
    set TB_NAME=%%~nf
    set MOD_NAME=!TB_NAME:tb_=!
    echo.
    echo Running !TB_NAME!...

    set RTL_FILES=
    if "!MOD_NAME!"=="reminder_subsystem" (
        set RTL_FILES=rtl\reminder\*.v
    ) else (
        if exist rtl\reminder\!MOD_NAME!.v set RTL_FILES=rtl\reminder\!MOD_NAME!.v
        if exist rtl\configuration\!MOD_NAME!.v set RTL_FILES=rtl\configuration\!MOD_NAME!.v
        if exist rtl\timing\!MOD_NAME!.v set RTL_FILES=rtl\timing\!MOD_NAME!.v
        if exist rtl\events\!MOD_NAME!.v set RTL_FILES=rtl\events\!MOD_NAME!.v
        if exist rtl\peripherals\!MOD_NAME!.v set RTL_FILES=rtl\peripherals\!MOD_NAME!.v
        if exist rtl\communication\!MOD_NAME!.v set RTL_FILES=rtl\communication\!MOD_NAME!.v
    )

    iverilog -g2012 -o sim\build\!TB_NAME!.vvp !RTL_FILES! %%f
    if !ERRORLEVEL! neq 0 (
        echo [COMPILE ERROR] %%f
        set /a FAILED+=1
    ) else (
        vvp sim\build\!TB_NAME!.vvp
        if !ERRORLEVEL! neq 0 (
            echo [SIMULATION FAILED] !TB_NAME!
            set /a FAILED+=1
        ) else (
            if exist !TB_NAME!.vcd (
                python scripts\waveform_screenshot.py !TB_NAME!.vcd pictures\!TB_NAME!_waveform.png "!TB_NAME! Waveform"
                del !TB_NAME!.vcd
            )
        )
    )
)

echo.
echo ===================================================
if %FAILED% equ 0 (
    echo   ALL TESTS PASSED (%TOTAL%/%TOTAL%)
    echo   Screenshots updated in pictures\
) else (
    echo   TESTS FAILED: %FAILED%/%TOTAL%
)
echo ===================================================
exit /b %FAILED%
