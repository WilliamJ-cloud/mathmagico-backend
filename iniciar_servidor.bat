@echo off
chcp 65001 > nul
title MathMágico — Servidor

echo.
echo  ╔══════════════════════════════════════════════╗
echo  ║          MathMágico — Backend                ║
echo  ╚══════════════════════════════════════════════╝
echo.
echo  Elige como exponer el servidor al celular:
echo.
echo    [1] localhost.run  (SSH incorporado en Windows — MAS SEGURO)
echo    [2] Serveo.net     (SSH incorporado en Windows)
echo    [3] LocalTunnel    (Node.js — ya instalado)
echo    [4] Solo WiFi local (sin tunel, misma red)
echo.
set /p OPC="  Tu eleccion [1-4]: "

:: Ir a la carpeta del backend
cd /d "%~dp0backend"

:: Activar entorno virtual si existe
if exist "venv\Scripts\activate.bat" (
    call venv\Scripts\activate.bat
)

echo.
echo  [1/2] Iniciando backend FastAPI en puerto 8000...
start "MathMagico-Backend" cmd /k "uvicorn main:app --host 0.0.0.0 --port 8000 --reload"

timeout /t 4 /nobreak > nul

echo  [2/2] Creando tunel publico...
echo.
echo  ─────────────────────────────────────────────────────
echo  IMPORTANTE: Copia la URL que aparezca (https://...)
echo  Luego en la app: Portal Profesor > Configurar servidor
echo  Pega la URL + /api/v1  (ej: https://xxx.loca.lt/api/v1)
echo  ─────────────────────────────────────────────────────
echo.

if "%OPC%"=="1" (
    echo  Usando localhost.run via SSH (sin descargas)...
    echo  La URL aparecera como:  https://xxxxxxxx.localhost.run
    echo.
    ssh -R 80:localhost:8000 nokey@localhost.run
) else if "%OPC%"=="2" (
    echo  Usando Serveo.net via SSH (sin descargas)...
    echo  La URL aparecera como:  https://serveo.net
    echo.
    ssh -R 80:localhost:8000 serveo.net
) else if "%OPC%"=="3" (
    echo  Usando LocalTunnel via Node.js...
    echo  La URL aparecera como:  https://xxx.loca.lt
    echo.
    npx localtunnel --port 8000
) else if "%OPC%"=="4" (
    echo  Modo WiFi local — sin tunel.
    echo  Asegurate que el celular y la PC esten en la misma red WiFi.
    echo.
    for /f "tokens=2 delims=:" %%A in ('ipconfig ^| findstr /c:"IPv4"') do (
        set IP=%%A
    )
    echo  Tu IP local es probablemente: %IP%
    echo  En la app usa: http://[TU_IP]:8000/api/v1
    echo.
    pause
) else (
    echo  Opcion no valida. Usando localhost.run por defecto...
    ssh -R 80:localhost:8000 nokey@localhost.run
)

echo.
echo  Servidor detenido.
pause
