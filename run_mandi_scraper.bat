@echo off
title FarmTech Mandi Price Scraper
cd /d "%~dp0"
echo =================================================================
echo   Starting FarmTech Live Mandi Price Scraper...
echo =================================================================
python scripts\mandi_price_scraper.py
echo.
pause
