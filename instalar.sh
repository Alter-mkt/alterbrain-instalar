#!/bin/bash
# Instalador do AlterBrain para Mac. Traz o Python 3.12 e o GitHub CLI para a pasta do usuário (sem administrador),
# entra no GitHub pelo navegador, baixa o AlterBrain na versão pronta mais nova e chama `alterbrain setup`.
# Rodar de novo confere cada peça e refaz só o que falta.

set -euo pipefail

# ---------------------------------------------------------------------------------------------------------------------
# Versões fixadas. Para trocar, veja instalador/LEIA.md (a cada troca, URL, versão e SHA-256 mudam juntos).
# ---------------------------------------------------------------------------------------------------------------------
GH_VERSAO="2.103.3"
GH_URL_ARM64="https://github.com/cli/cli/releases/download/v2.103.3/gh_2.103.3_macOS_arm64.zip"
GH_SHA256_ARM64="d700207eae9ae98fe2b89535c2c087c07823d4628c56364695a5a07ef311c062"
GH_URL_AMD64="https://github.com/cli/cli/releases/download/v2.103.3/gh_2.103.3_macOS_amd64.zip"
GH_SHA256_AMD64="a2f86418f4350ae6e9ec60d5000bdf7665728436946a97fc27fe50e6ae752682"

PYTHON_VERSAO="3.12.16"
PYTHON_URL_ARM64="https://github.com/astral-sh/python-build-standalone/releases/download/20261026/cpython-3.12.16%2B20261026-aarch64-apple-darwin-install_only.tar.gz"
PYTHON_SHA256_ARM64="fbf4afef53c2a6b72bb741bc06d5671a9dfaf87bd84e5aa73ac9b3d0d589f14e"
PYTHON_URL_AMD64="https://github.com/astral-sh/python-build-standalone/releases/download/20261026/cpython-3.12.16%2B20261026-x86_64-apple-darwin-install_only.tar.gz"
PYTHON_SHA256_AMD64="a962e47df522889eaa7ff0d6a56203f1079f68aabb65ffdbe8455f362bc769f3"

# Só para teste (nunca documentadas ao gestor).
BASE="${ALTERBRAIN_BASE:-$HOME/AlterBrain}"
REPOSITORIO="${ALTERBRAIN_REPOSITORIO:-https://github.com/Alter-mkt/AlterBrain.git}"
PYTHON_PRONTO="${ALTERBRAIN_PYTHON_PRONTO:-}"
GH_PRONTO="${ALTERBRAIN_GH_PRONTO:-}"

export GIT_TERMINAL_PROMPT=0

dizer() { printf '%s\n' "$*"; }
falhar() { printf 'Erro: %s\n' "$*" >&2; exit 1; }

# 1. Mac e git ---------------------------------------------------------------------------------------------------------
[ "$(uname -s)" = "Darwin" ] || falhar "este instalador é para Mac."

if ! git --version >/dev/null 2>&1; then
  xcode-select --install >/dev/null 2>&1 || true
  falhar "termine a instalação das ferramentas da Apple e rode de novo."
fi

case "$(uname -m)" in
  arm64)  GH_URL="$GH_URL_ARM64";  GH_SHA256="$GH_SHA256_ARM64";  PYTHON_URL="$PYTHON_URL_ARM64";  PYTHON_SHA256="$PYTHON_SHA256_ARM64" ;;
  x86_64) GH_URL="$GH_URL_AMD64";  GH_SHA256="$GH_SHA256_AMD64";  PYTHON_URL="$PYTHON_URL_AMD64";  PYTHON_SHA256="$PYTHON_SHA256_AMD64" ;;
  *) falhar "não conheço o processador deste Mac ($(uname -m))." ;;
esac

LOCAL="$BASE/Local"
BIN="$LOCAL/bin"
PYTHON_DIR="$LOCAL/python"
CLONES="$LOCAL/AlterBrain"
AMBIENTE="$LOCAL/ambiente"
TEMP="$LOCAL/.baixando"

mkdir -p "$BIN" "$CLONES"
rm -rf "$TEMP"
mkdir -p "$TEMP"
trap 'rm -rf "$TEMP"' EXIT

# Baixa $1 para $3 e confere o SHA-256 $2; código diferente apaga o arquivo e para.
baixar_conferido() {
  local url="$1" esperado="$2" destino="$3" tempo="${4:-300}" obtido
  curl -fsSL --retry 3 --connect-timeout 20 --max-time "$tempo" -o "$destino" "$url" || { rm -f "$destino"; falhar "não consegui baixar $url"; }
  obtido="$(shasum -a 256 "$destino" | awk '{print $1}')"
  if [ "$obtido" != "$esperado" ]; then
    rm -f "$destino"
    falhar "o código SHA-256 do arquivo baixado não confere com o esperado; apaguei o arquivo por segurança. Tente de novo e, se repetir, avise o Weslei."
  fi
}

# 2. GitHub CLI ---------------------------------------------------------------------------------------------------------
if [ -n "$GH_PRONTO" ]; then
  GH="$GH_PRONTO"
else
  GH="$BIN/gh"
  if [ -x "$GH" ] && [ "$(cat "$BIN/gh.sha256" 2>/dev/null || true)" = "$GH_SHA256" ]; then
    dizer "GitHub CLI $GH_VERSAO já está em Local/bin."
  else
    dizer "Baixando o GitHub CLI $GH_VERSAO..."
    baixar_conferido "$GH_URL" "$GH_SHA256" "$TEMP/gh.zip" 300
    rm -f "$GH" "$BIN/gh.sha256"
    unzip -q -o -j "$TEMP/gh.zip" "*/bin/gh" -d "$TEMP/gh" || falhar "não consegui abrir o arquivo do GitHub CLI."
    mv "$TEMP/gh/gh" "$GH"
    chmod +x "$GH"
    printf '%s\n' "$GH_SHA256" > "$BIN/gh.sha256"
  fi
fi

# 3. Python 3.12 autocontido --------------------------------------------------------------------------------------------
if [ -n "$PYTHON_PRONTO" ]; then
  PYTHON="$PYTHON_PRONTO"
else
  PYTHON="$PYTHON_DIR/bin/python3.12"
  if [ -x "$PYTHON" ] && [ "$(cat "$PYTHON_DIR/.sha256" 2>/dev/null || true)" = "$PYTHON_SHA256" ]; then
    dizer "Python $PYTHON_VERSAO já está em Local/python."
  else
    dizer "Baixando o Python $PYTHON_VERSAO..."
    baixar_conferido "$PYTHON_URL" "$PYTHON_SHA256" "$TEMP/python.tar.gz" 600
    mkdir -p "$TEMP/python"
    tar -xzf "$TEMP/python.tar.gz" -C "$TEMP/python" || falhar "não consegui abrir o arquivo do Python."
    [ -x "$TEMP/python/python/bin/python3.12" ] || falhar "o arquivo do Python veio sem o que eu esperava."
    rm -rf "$PYTHON_DIR"
    mv "$TEMP/python/python" "$PYTHON_DIR"
    printf '%s\n' "$PYTHON_SHA256" > "$PYTHON_DIR/.sha256"
  fi
fi

# 4. Login no GitHub ----------------------------------------------------------------------------------------------------
if "$GH" auth status >/dev/null 2>&1; then
  dizer "GitHub já está conectado."
else
  dizer "Vou abrir o navegador para você entrar no GitHub. Siga as instruções que aparecem aqui."
  "$GH" auth login --web --git-protocol https || falhar "não consegui entrar no GitHub."
fi
"$GH" auth setup-git || falhar "não consegui ligar o git ao login do GitHub."

# 5. Tag pronta mais nova, clone, ambiente e pacote ---------------------------------------------------------------------
# Pasta já instalada: o script não mexe na versão do pacote (isso é de `alterbrain atualizar-pacote`), só chama o setup.
if [ -x "$AMBIENTE/bin/python" ] && [ -x "$AMBIENTE/bin/alterbrain" ] \
   && "$AMBIENTE/bin/python" -I -c "import alterbrain" >/dev/null 2>&1; then
  dizer "AlterBrain já está instalado."
else
  GIT_REDE=(-c http.lowSpeedLimit=1000 -c http.lowSpeedTime=60)
  LISTA="$(git "${GIT_REDE[@]}" ls-remote --tags --refs "$REPOSITORIO" 2>/dev/null)" \
    || falhar "não consegui ler o AlterBrain no GitHub. Confira se o login é o da conta que o Weslei liberou."
  TAG="$(printf '%s\n' "$LISTA" | awk '{print $2}' | sed 's|^refs/tags/||' \
    | grep -E '^v[0-9]+\.[0-9]+\.[0-9]+$' | sed 's/^v//' | sort -t. -k1,1n -k2,2n -k3,3n | tail -n 1)" || true
  [ -n "$TAG" ] || falhar "não achei nenhuma versão pronta do AlterBrain."
  VERSAO="$TAG"
  CLONE="$CLONES/$VERSAO"

  if [ -f "$CLONE/pyproject.toml" ]; then
    dizer "AlterBrain $VERSAO já está baixado."
  else
    dizer "Baixando o AlterBrain $VERSAO..."
    rm -rf "$CLONE" "$TEMP/clone"
    git "${GIT_REDE[@]}" clone --quiet --depth 1 --branch "v$VERSAO" "$REPOSITORIO" "$TEMP/clone" \
      || falhar "não consegui baixar o AlterBrain $VERSAO."
    mv "$TEMP/clone" "$CLONE"
  fi

  dizer "Criando o ambiente do AlterBrain..."
  rm -rf "$AMBIENTE"
  "$PYTHON" -m venv "$AMBIENTE" || { rm -rf "$AMBIENTE"; falhar "não consegui criar o ambiente do AlterBrain."; }
  dizer "Instalando o AlterBrain $VERSAO..."
  "$AMBIENTE/bin/python" -m pip install --quiet "$CLONE" \
    || { rm -rf "$AMBIENTE"; falhar "não consegui instalar o AlterBrain $VERSAO."; }
  # o `alterbrain atualizar-pacote` busca as versões novas no mesmo repositório de onde o pacote veio
  printf '%s\n' "$REPOSITORIO" > "$CLONES/origem"
fi

# 6. Setup --------------------------------------------------------------------------------------------------------------
rm -rf "$TEMP"  # o exec abaixo não roda o trap
exec "$AMBIENTE/bin/alterbrain" setup --base "$BASE"
