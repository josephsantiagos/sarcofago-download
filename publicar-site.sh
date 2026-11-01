#!/usr/bin/env bash
# Publica a página do jogo e a versão para navegador no GitHub Pages (ramo gh-pages, um commit só a cada vez: as
# versões antigas do jogo não se acumulam no repositório).
#   ./publicar-site.sh [pasta da build web]   (padrão: ../sarcofago/Builds/Web)
#   SO_MONTAR=/pasta ./publicar-site.sh        só monta o site na pasta, para testar (python3 -m http.server)
set -euo pipefail
cd "$(dirname "$0")"
WEB="${1:-../sarcofago/Builds/Web}"
VERSAO=$(grep -m1 "bundleVersion:" ../sarcofago/ProjectSettings/ProjectSettings.asset | awk '{print $2}')
PARTE=$((90 * 1024 * 1024))   # o GitHub recusa arquivo acima de 100 MB

[ -f "$WEB/Build/Web.loader.js" ] || { echo "Falta a build web em $WEB (ConfigurarWeb.GerarWeb)"; exit 1; }
if [ -n "${SO_MONTAR:-}" ]; then
  SAIDA="$SO_MONTAR"; rm -rf "$SAIDA"; mkdir -p "$SAIDA"
else
  SAIDA=$(mktemp -d)
  trap 'rm -rf "$SAIDA"' EXIT
fi

cp -r site/. "$SAIDA/"
mkdir -p "$SAIDA/jogar/Build"
touch "$SAIDA/.nojekyll"
sed -i "s|<span data-versao>[^<]*</span>|<span data-versao>$VERSAO</span>|" "$SAIDA/index.html"

cp "$WEB/Build/Web.loader.js" "$SAIDA/jogar/Build/"
framework=$(cd "$WEB/Build" && ls Web.framework.js*)
wasm=$(cd "$WEB/Build" && ls Web.wasm*)
dados=$(cd "$WEB/Build" && ls Web.data*)
cp "$WEB/Build/$framework" "$WEB/Build/$wasm" "$SAIDA/jogar/Build/"
[ -d "$WEB/StreamingAssets" ] && cp -r "$WEB/StreamingAssets" "$SAIDA/jogar/"
split -b "$PARTE" -d -a 3 "$WEB/Build/$dados" "$SAIDA/jogar/Build/$dados."
partes=$(cd "$SAIDA/jogar/Build" && ls "$dados".* | python3 -c 'import sys,json; print(json.dumps([l.strip() for l in sys.stdin if l.strip()]))')
tamanho=$(stat -c %s "$WEB/Build/$dados")
cat > "$SAIDA/jogar/Build/manifesto.json" <<EOF
{"versao": "$VERSAO", "loader": "Web.loader.js", "framework": "$framework", "wasm": "$wasm", "dados": $partes, "tamanho": $tamanho}
EOF

grande=$(find "$SAIDA" -type f -size +95M)
[ -z "$grande" ] || { echo "Arquivo grande demais para o GitHub: $grande"; exit 1; }

if [ -n "${SO_MONTAR:-}" ]; then echo "Montado em $SAIDA (versão $VERSAO)"; exit 0; fi
origem=$(git remote get-url origin)
(
  cd "$SAIDA"
  git init -q -b gh-pages
  git add -A
  git -c user.name="$(git -C "$OLDPWD" config user.name)" -c user.email="$(git -C "$OLDPWD" config user.email)" \
    commit -q -m "Página do Sarcófago e versão $VERSAO para navegador"
  git push -q --force "$origem" gh-pages
)
echo "Publicado: versão $VERSAO, $(du -sh "$SAIDA" --exclude=.git | cut -f1)"
