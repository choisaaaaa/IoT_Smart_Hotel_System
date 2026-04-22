@echo off
REM MQTT TLS Certificate Generation Script
REM This generates self-signed certificates for development/testing

echo Generating MQTT TLS certificates...

REM Create certs directory
if not exist certs mkdir certs
cd certs

echo 1. Generating CA private key...
openssl genrsa -out ca.key 2048

echo 2. Generating CA certificate...
openssl req -new -x509 -days 3650 -key ca.key -out ca.crt ^
  -subj "/C=CN/ST=Zhejiang/L=Hangzhou/O=HuiZhu IoT/CN=IoT MQTT CA"

echo 3. Generating server private key...
openssl genrsa -out server.key 2048

echo 4. Generating server CSR...
openssl req -new -key server.key -out server.csr ^
  -subj "/C=CN/ST=Zhejiang/L=Hangzhou/O=HuiZhu IoT/CN=iot-mqtt-server"

echo 5. Signing server certificate with CA...
openssl x509 -req -days 3650 -in server.csr -CA ca.crt -CAkey ca.key ^
  -CAcreateserial -out server.crt ^
  -extfile ../server_ext.cnf

echo 6. Generating client private key...
openssl genrsa -out client.key 2048

echo 7. Generating client CSR...
openssl req -new -key client.key -out client.csr ^
  -subj "/C=CN/ST=Zhejiang/L=Hangzhou/O=HuiZhu IoT/CN=iot-mqtt-client"

echo 8. Signing client certificate with CA...
openssl x509 -req -days 3650 -in client.csr -CA ca.crt -CAkey ca.key ^
  -CAcreateserial -out client.crt

echo.
echo Certificate generation completed!
echo.
echo Generated files:
dir /b

echo.
echo IMPORTANT:
echo - These are self-signed certificates for development only
echo - Production should use certificates from a trusted CA
echo - Copy ca.crt, server.crt, server.key to MQTT broker
echo - Copy ca.crt, client.crt, client.key to clients

pause
