{
  writeShellApplication,
  python3,
  ...
}:
writeShellApplication {
  name = "pg-scram-sha256";
  runtimeInputs = [python3];
  text = ''
    if [ $# -ne 1 ]; then
      echo "Usage: pg-scram-sha256 <password>" >&2
      exit 1
    fi
    python3 - "$1" <<'EOF'
import hashlib, hmac, os, base64, sys
password = sys.argv[1]
iterations = 4096
salt = os.urandom(16)
salted_pw = hashlib.pbkdf2_hmac('sha256', password.encode('utf-8'), salt, iterations)
client_key = hmac.new(salted_pw, b'Client Key', hashlib.sha256).digest()
stored_key = hashlib.sha256(client_key).digest()
server_key = hmac.new(salted_pw, b'Server Key', hashlib.sha256).digest()
print("SCRAM-SHA-256$%d:%s$%s:%s" % (iterations, base64.b64encode(salt).decode(), base64.b64encode(stored_key).decode(), base64.b64encode(server_key).decode()))
EOF
  '';
}
