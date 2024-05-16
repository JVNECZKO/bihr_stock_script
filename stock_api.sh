#!/bin/bash

# Init Config
userName="ApiUserName"
passWord="ApiPasswd"
apiUrl="https://api.bihr.net/api/v2.1"
downloadPath="defaultpath"
newFileName="stocks.csv"

# Check if catalog available if not create folder
if [ ! -d "$downloadPath" ]; then
  echo "Katalog $downloadPath nie istnieje. Tworzenie katalogu."
  mkdir -p "$downloadPath"
fi

# Brearer token generation
response=$(curl -s -X 'POST' \
  "$apiUrl/Authentication/Token" \
  -H 'Content-Type: multipart/form-data' \
  -F "UserName=$userName" \
  -F "PassWord=$passWord")

echo "Odpowiedź serwera przy żądaniu tokena: $response"

token=$(echo $response | grep -oP '"access_token":"\K[^"]*')

if [ -z "$token" ]; then
  echo "Nie udało się uzyskać tokena. Sprawdź odpowiedź serwera."
  exit 1
fi

echo "Uzyskano token: $token"

# Starting ZIP file generation
response=$(curl -s -X 'POST' \
  "$apiUrl/Catalog/ZIP/CSV/Stocks/Full" \
  -H "Authorization: Bearer $token" \
  -H 'accept: text/plain')

echo "Odpowiedź serwera przy próbie rozpoczęcia generowania pliku: $response"

ticketId=$(echo $response | grep -oP '"TicketId":"\K[^"]*')

if [ -z "$ticketId" ]; then
  echo "Nie udało się zainicjować generowania pliku. Sprawdź odpowiedź serwera."
  exit 1
fi

echo "Ticket ID: $ticketId"

# Checking about file generation status
while true; do
  statusResponse=$(curl -s -X 'GET' \
    "$apiUrl/Catalog/GenerationStatus?ticketId=$ticketId" \
    -H "Authorization: Bearer $token" \
    -H 'accept: text/plain')

  status=$(echo $statusResponse | grep -oP '"RequestStatus":"\K[^"]*')

  echo "Status: $status"

  if [ "$status" == "DONE" ]; then
    downloadId=$(echo $statusResponse | grep -oP '"DownloadId":"\K[^"]*')
    echo "Generowanie pliku zakończone. Download ID: $downloadId"
    break
  fi
  sleep 2
done

# Download generated ZIP File
if [ -z "$downloadId" ]; then
  echo "Brak DownloadId, nie można pobrać pliku."
  exit 1
fi

zipFilePath="$downloadPath/temp_stocks.zip"
echo "Ścieżka zapisu ZIP: $zipFilePath"

curl -s -X 'GET' \
  "$apiUrl/Catalog/GeneratedFile?downloadId=$downloadId" \
  -H "Authorization: Bearer $token" \
  -H 'accept: */*' \
  -o "$zipFilePath"

# Unzip .zip file
if [ -f "$zipFilePath" ]; then
  echo "Plik ZIP został pobrany. Rozpoczynanie wypakowywania..."
  unzip -o "$zipFilePath" -d "$downloadPath" # Switch -o deny asking about override
  rm "$zipFilePath" # Optional: Remove ZIP after extracting in root directory 
  
  # Changing CSV filename
  csvFilePath=$(find $downloadPath -name '*.csv')
  if [ -n "$csvFilePath" ]; then
    mv "$csvFilePath" "$downloadPath/$newFileName"
    echo "Plik CSV został zapisany jako: $downloadPath/$newFileName"
  else
    echo "Nie znaleziono pliku CSV po wypakowaniu."
  fi
else
  echo "Nie udało się pobrać pliku ZIP. Sprawdź logi curl."
fi
