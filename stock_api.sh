#!/bin/bash

# Konfiguracja
userName="usrname"
passWord="passwd"
apiUrl="https://api.bihr.net/api/v2.1"
downloadPath="stocks"  # Ścieżka relatywna od katalogu, w którym jest uruchamiany skrypt
newFileName="stocks.csv"

# Sprawdzenie, czy katalog na pliki istnieje, jeśli nie - próba utworzenia
if [ ! -d "$downloadPath" ]; then
  echo "Tworzenie katalogu: $downloadPath"
  mkdir -p "$downloadPath"
fi

# Generowanie tokena
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

# Rozpoczęcie generowania pliku ZIP
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

# Odpytywanie o status generacji pliku
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

# Pobieranie pliku ZIP
zipFilePath="$downloadPath/temp_stocks.zip"
echo "Ścieżka zapisu ZIP: $zipFilePath"

curl -s -X 'GET' \
  "$apiUrl/Catalog/GeneratedFile?downloadId=$downloadId" \
  -H "Authorization: Bearer $token" \
  -H 'accept: */*' \
  -o "$zipFilePath"

# Wypakowanie pliku ZIP
echo "Rozpoczynanie wypakowywania..."
unzip -o "$zipFilePath" -d "$downloadPath"
rm "$zipFilePath"

# Zmiana nazwy pliku CSV
csvFilePath=$(find $downloadPath -maxdepth 1 -type f -name '*.csv' -print -quit)
if [ -f "$downloadPath/$newFileName" ]; then
  rm "$downloadPath/$newFileName"
fi
if [ -n "$csvFilePath" ]; then
  mv "$csvFilePath" "$downloadPath/$newFileName"
  echo "Plik CSV został zapisany jako: $downloadPath/$newFileName"
else
  echo "Nie znaleziono pliku CSV po wypakowaniu."
fi
