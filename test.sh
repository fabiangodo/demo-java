#!/bin/bash

# Cargar variables de entorno desde .env
if [ -f .env ]; then
  set -o allexport
  source .env
  set +o allexport
else
  echo "❌ Error: No se encontró el archivo .env"
  exit 1
fi

# Validar que existan las variables requeridas
if [ -z "$AZURE_TENANT_ID" ] || [ -z "$AZURE_CLIENT_ID" ] || [ -z "$AZURE_CLIENT_SECRET" ] || [ -z "$API_URL" ]; then
  echo "❌ Error: Faltan variables necesarias en el archivo .env"
  exit 1
fi

echo "🔑 Solicitando Access Token a Microsoft Entra ID..."

TOKEN_RESPONSE=$(curl -s -X POST "https://login.microsoftonline.com/${AZURE_TENANT_ID}/oauth2/v2.0/token" \
  -H "Content-Type: application/x-www-form-urlencoded" \
  -d "client_id=${AZURE_CLIENT_ID}" \
  -d "scope=${AZURE_CLIENT_ID}/.default" \
  -d "client_secret=${AZURE_CLIENT_SECRET}" \
  -d "grant_type=client_credentials")

# Parsear el token usando Python3 integrados en el sistema
ACCESS_TOKEN=$(echo "$TOKEN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin).get('access_token', ''))" 2>/dev/null)

if [ -z "$ACCESS_TOKEN" ] || [ "$ACCESS_TOKEN" == "None" ]; then
  echo "❌ Error al obtener el token:"
  echo "$TOKEN_RESPONSE"
  exit 1
fi

echo "✅ Token obtenido exitosamente."
echo "🚀 Enviando petición a $API_URL..."
echo ""

curl -i -X GET "$API_URL" \
  -H "Authorization: Bearer $ACCESS_TOKEN"