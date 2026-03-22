#!/bin/bash
# FORGE — Setup project (local, no global changes)
# Creates .forge/ in the target project and generates LLM adapters

set -e

FORGE_REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(pwd)"

# Prevent running inside the FORGE repo itself
if [ "$PROJECT_ROOT" = "$FORGE_REPO" ]; then
  echo "❌ No corras este script dentro del repo FORGE."
  echo "   Ejecutalo desde el root de tu proyecto:"
  echo "   cd /tu/proyecto && bash $FORGE_REPO/setup-project.sh"
  exit 1
fi

# ─── Tool detection ────────────────────────────────────────────────────────────

detect_claude() {
  command -v claude &>/dev/null
}

detect_cursor() {
  command -v cursor &>/dev/null || \
  [ -d "/Applications/Cursor.app" ] || \
  [ -d "$HOME/AppData/Local/Programs/cursor" ]
}

detect_copilot() {
  local ext_dir1="$HOME/.vscode/extensions"
  local ext_dir2="$HOME/AppData/Roaming/Code/User/extensions"
  ([ -d "$ext_dir1" ] && ls "$ext_dir1" 2>/dev/null | grep -qi "github.copilot") || \
  ([ -d "$ext_dir2" ] && ls "$ext_dir2" 2>/dev/null | grep -qi "github.copilot")
}

detect_windsurf() {
  command -v windsurf &>/dev/null || \
  [ -d "/Applications/Windsurf.app" ] || \
  [ -d "$HOME/AppData/Local/Programs/windsurf" ]
}

detect_gemini() {
  command -v gemini &>/dev/null
}

# ─── Install instructions ──────────────────────────────────────────────────────

install_instructions() {
  local tool="$1"
  case "$tool" in
    claude)   echo "npm install -g @anthropic-ai/claude-code" ;;
    cursor)   echo "https://cursor.com/download" ;;
    copilot)  echo "Extensión VS Code → https://marketplace.visualstudio.com/items?itemName=GitHub.copilot" ;;
    windsurf) echo "https://windsurf.com/download" ;;
    gemini)   echo "npm install -g @google/gemini-cli" ;;
  esac
}

# ─── Adapter generators ────────────────────────────────────────────────────────

generate_claude_adapter() {
  mkdir -p ".claude/skills"
  for skill_file in ".forge/skills"/forge-*.md; do
    local name
    name="$(basename "$skill_file" .md)"
    mkdir -p ".claude/skills/$name"
    cp "$skill_file" ".claude/skills/$name/SKILL.md"
  done
  cat > ".claude/CLAUDE.md" <<'CLAUDEMD'
# Forge — Activo

Este proyecto usa metodología Forge para desarrollo guiado por fases.
Pipeline: SPIKE → SPEC → BUILD → VERIFY → CLOSE (phase-gated, sin shortcuts).

## Estado del ciclo
Leé `.forge/FORGE.md` antes de cualquier `forge *` command.

## Configuración
Stack y modelos: `.forge/config.yaml`

## Comandos disponibles
| Comando | Cuándo usarlo |
|---------|---------------|
| `forge new "nombre"` | Iniciar nuevo ciclo de feature |
| `forge spike` | Investigación técnica (opcional) |
| `forge spec` | Generar SPEC unificada (requirements + domain + arch + UI) |
| `forge build` | Implementar con ciclo red-green-refactor |
| `forge verify` | Validar implementación vs SPEC |
| `forge approve` | Aprobar la fase actual |
| `forge status` | Ver estado del ciclo activo |
| `forge close` | Archivar feature completada |

## Skills
Los skills se cargan automáticamente desde `.claude/skills/`.
CLAUDEMD
  echo "  ✅ Claude adapter generado"
}

generate_cursor_adapter() {
  mkdir -p ".cursor/rules"
  for skill_file in ".forge/skills"/forge-*.md; do
    local name
    name="$(basename "$skill_file" .md)"
    cp "$skill_file" ".cursor/rules/$name.mdc"
  done
  cat > ".cursor/rules/forge-context.mdc" <<'CURSORMDC'
---
description: Forge methodology — active for all forge commands
---
# Forge — Activo
Pipeline: SPIKE → SPEC → BUILD → VERIFY → CLOSE.
Estado: `.forge/FORGE.md` | Config: `.forge/config.yaml`
Antes de cualquier `forge *` command, leé `.forge/FORGE.md`.
CURSORMDC
  echo "  ✅ Cursor adapter generado"
}

generate_copilot_adapter() {
  mkdir -p ".github"
  cat > ".github/copilot-instructions.md" <<'COPILOTMD'
# Forge — Active
This project uses Forge methodology. Pipeline: SPIKE → SPEC → BUILD → VERIFY → CLOSE (no shortcuts).
Active cycle: `.forge/FORGE.md` | Config: `.forge/config.yaml` | Skills: `.forge/skills/`
Before any `forge *` command, read `.forge/FORGE.md`.
COPILOTMD
  echo "  ✅ Copilot adapter generado"
}

generate_windsurf_adapter() {
  cat > ".windsurfrules" <<'WINDSURFMD'
# Forge — Activo
Pipeline: SPIKE → SPEC → BUILD → VERIFY → CLOSE. Sin shortcuts.
Estado: .forge/FORGE.md | Config: .forge/config.yaml | Skills: .forge/skills/
Antes de forge *, leé .forge/FORGE.md.
WINDSURFMD
  echo "  ✅ Windsurf adapter generado"
}

generate_gemini_adapter() {
  # Gemini CLI respects .gitignore — copies Forge files into .gemini/ (Gemini's native dir).
  # All .forge/ path references are rewritten to .gemini/forge/ so Gemini can read them.
  # Note: chat mode support is planned for a future version.
  mkdir -p ".gemini/forge/skills" ".gemini/forge/validation" ".gemini/forge/templates"

  # Core files — rewrite .forge/ paths
  sed 's|\.forge/|.gemini/forge/|g' ".forge/FORGE.md"       > ".gemini/forge/FORGE.md"
  sed 's|\.forge/|.gemini/forge/|g' ".forge/KNOWLEDGE.md"   > ".gemini/forge/KNOWLEDGE.md"
  sed 's|\.forge/|.gemini/forge/|g' ".forge/config.yaml"    > ".gemini/forge/config.yaml"

  # Skills — rewrite .forge/ paths
  for f in ".forge/skills"/forge-*.md; do
    sed 's|\.forge/|.gemini/forge/|g' "$f" > ".gemini/forge/skills/$(basename "$f")"
  done

  # Validation assertions — rewrite .forge/ paths
  for f in ".forge/validation/"*.yaml; do
    sed 's|\.forge/|.gemini/forge/|g' "$f" > ".gemini/forge/validation/$(basename "$f")"
  done

  # Templates — rewrite .forge/ paths
  for f in ".forge/templates/"*.md; do
    sed 's|\.forge/|.gemini/forge/|g' "$f" > ".gemini/forge/templates/$(basename "$f")"
  done

  # Stack skills (optional)
  if [ -d ".forge/stack-skills" ]; then
    mkdir -p ".gemini/forge/stack-skills"
    for f in ".forge/stack-skills/"*.md; do
      sed 's|\.forge/|.gemini/forge/|g' "$f" > ".gemini/forge/stack-skills/$(basename "$f")"
    done
  fi

  mkdir -p ".gemini/forge/features/activo" ".gemini/forge/features/closed"

  [ -f "GEMINI.md" ] && rm "GEMINI.md"

  echo "  ✅ Gemini adapter generado (.gemini/forge/)"
}

# ─── Main ──────────────────────────────────────────────────────────────────────

cat <<'BANNER'

        ⠀⠀⠀⠀⠀⠀⣀⣤⣤⣤⣤⣀⠀⠀⠀⠀⠀⠀
        ⠀⠀⠀⠀⣴⣿⣿⣿⣿⣿⣿⣿⣷⣄⠀⠀⠀⠀
        ⠀⠀⢀⣾⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣷⡀⠀⠀
        ⠀⠀⣾⣿⣿⣿⣿⡿⠋⠉⠙⢿⣿⣿⣿⣷⠀⠀
        ⠀⠀⣿⣿⣿⣿⡟⠀⠀⠀⠀⠀⢻⣿⣿⣿⡇⠀
        ⠀⠀⣿⣿⣿⣿⠁⠀⠀⠀⠀⠀⠈⣿⣿⣿⡇⠀
        ⠀⠀⢿⣿⣿⣿⡀⠀⠀⠀⠀⠀⢀⣿⣿⣿⡇⠀
        ⠀⠀⠘⣿⣿⣿⣿⣄⠀⠀⠀⣠⣾⣿⣿⣿⠃⠀
        ⢀⣤⣤⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣤⡀
        ⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿
        ⠈⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠁
        ⠀⠀⠈⠻⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠟⠁⠀⠀
        ⠀⠀⠀⠀⠈⠛⢿⣿⣿⣿⣿⡿⠛⠁⠀⠀⠀⠀
        ⠀⠀⠀⠀⠀⠀⠀⠈⠉⠉⠁⠀⠀⠀⠀⠀⠀⠀

  ███████╗ ██████╗ ██████╗  ██████╗ ███████╗
  ██╔════╝██╔═══██╗██╔══██╗██╔════╝ ██╔════╝
  █████╗  ██║   ██║██████╔╝██║  ███╗█████╗
  ██╔══╝  ██║   ██║██╔══██╗██║   ██║██╔══╝
  ██║     ╚██████╔╝██║  ██║╚██████╔╝███████╗
  ╚═╝      ╚═════╝ ╚═╝  ╚═╝ ╚═════╝ ╚══════╝
        AI-Assisted Development Pipeline v0.4
      SPIKE → SPEC → BUILD → VERIFY → CLOSE

BANNER

echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "Proyecto: $PROJECT_ROOT"
echo ""

# ─── STACK SETUP ──────────────────────────────────────────────────
setup_stack() {
  echo ""
  echo "¿Qué stack usa este proyecto?"
  echo "  1. android  (built-in)"
  echo "  2. kmp      (built-in)"
  echo "  3. otro     (genero una plantilla para completar)"
  echo ""
  echo -n "Elegí [1/2/3]: "
  read -r stack_choice

  case "$stack_choice" in
    1)
      STACK_NAME="android"
      cp "$FORGE_REPO/stacks/android.md" "$PROJECT_ROOT/.forge/stack-skills/android.md"
      echo "✅ Stack: android"
      ;;
    2)
      STACK_NAME="kmp"
      cp "$FORGE_REPO/stacks/kmp.md" "$PROJECT_ROOT/.forge/stack-skills/kmp.md"
      echo "✅ Stack: kmp"
      ;;
    3)
      echo -n "Nombre del stack (ej: python, react, node): "
      read -r custom_stack
      # sanitize: lowercase, no spaces
      STACK_NAME=$(echo "$custom_stack" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
      cp "$FORGE_REPO/stacks/TEMPLATE.md" "$PROJECT_ROOT/.forge/stack-skills/$STACK_NAME.md"
      # Replace {nombre} placeholder in the template
      sed -i.bak "s/{nombre}/$STACK_NAME/g" "$PROJECT_ROOT/.forge/stack-skills/$STACK_NAME.md"
      rm -f "$PROJECT_ROOT/.forge/stack-skills/$STACK_NAME.md.bak"
      echo "✅ Plantilla generada: .forge/stack-skills/$STACK_NAME.md"
      echo "   ⚠️  Completá todas las secciones antes de usar forge spec/build."
      ;;
    *)
      STACK_NAME="android"
      cp "$FORGE_REPO/stacks/android.md" "$PROJECT_ROOT/.forge/stack-skills/android.md"
      echo "⚠️  Opción no reconocida. Usando android por defecto."
      ;;
  esac

  # Copy TEMPLATE.md always (for reference)
  cp "$FORGE_REPO/stacks/TEMPLATE.md" "$PROJECT_ROOT/.forge/stack-skills/TEMPLATE.md"
}

# 1. Create .forge/ structure
mkdir -p .forge/features/activo .forge/features/closed
cp "$FORGE_REPO/FORGE.md"        .forge/FORGE.md
cp "$FORGE_REPO/templates/KNOWLEDGE.md"   .forge/KNOWLEDGE.md
cp "$FORGE_REPO/config.yaml"    .forge/config.yaml
mkdir -p .forge/templates && cp "$FORGE_REPO/templates/"*.md .forge/templates/
mkdir -p .forge/validation && cp "$FORGE_REPO/validation/"*.yaml .forge/validation/
mkdir -p .forge/stack-skills
mkdir -p .forge/skills        && cp "$FORGE_REPO/skills/forge-"*.md .forge/skills/
# Ensure all .forge files are readable (fixes Gemini CLI and other tools)
chmod -R u+r,go+r .forge/
echo "✅ .forge/ creado"
echo ""

# 1b. Stack setup
setup_stack

# Update stack in config.yaml
sed -i.bak "s/plataforma: android/plataforma: $STACK_NAME/g" "$PROJECT_ROOT/.forge/config.yaml"
rm -f "$PROJECT_ROOT/.forge/config.yaml.bak"
echo ""

# 2. Detect installed tools
DETECTED=()

detect_claude   && DETECTED+=("claude")
detect_cursor   && DETECTED+=("cursor")
detect_copilot  && DETECTED+=("copilot")
detect_windsurf && DETECTED+=("windsurf")
detect_gemini   && DETECTED+=("gemini")

# 3. Handle no tools found
if [ ${#DETECTED[@]} -eq 0 ]; then
  echo "⚠️  No se detectó ninguna herramienta de IA instalada."
  echo ""
  echo "Herramientas soportadas:"
  for tool in claude cursor copilot windsurf gemini; do
    echo "  • $tool → $(install_instructions "$tool")"
  done
  echo ""
  exit 0
fi

# 4. Print detected tools
echo "Herramientas detectadas:"
for tool in "${DETECTED[@]}"; do
  echo "  • $tool"
done
echo ""

# 5. Ask to generate adapters
read -r -p "¿Generar adaptadores para estas herramientas? [S/n] " confirm
if [[ "$confirm" =~ ^[Nn]$ ]]; then
  echo "Cancelado."
  exit 0
fi
echo ""

# 6. Ask for extra tools
read -r -p "¿Querés agregar alguna herramienta más? (Enter para continuar): " extra
if [ -n "$extra" ]; then
  case "$extra" in
    claude|cursor|copilot|windsurf|gemini)
      # Check if already detected
      already=false
      for t in "${DETECTED[@]}"; do
        [ "$t" = "$extra" ] && already=true && break
      done
      if $already; then
        echo "Ya estaba detectada ✅"
      else
        # Check if installed
        if detect_"$extra" 2>/dev/null; then
          DETECTED+=("$extra")
          echo "  Agregada: $extra"
        else
          echo "  ⚠️  $extra no está instalado."
          echo "  Instalación: $(install_instructions "$extra")"
          echo "  Reejecutá setup después de instalar."
        fi
      fi
      ;;
    *)
      echo "Herramienta no reconocida: $extra"
      ;;
  esac
  echo ""
fi

# 7. Update .gitignore
GITIGNORE="$PROJECT_ROOT/.gitignore"

# Helper: append entry only if not already present
gitignore_add() {
  local entry="$1"
  if ! grep -qF "$entry" "$GITIGNORE" 2>/dev/null; then
    printf "%s\n" "$entry" >> "$GITIGNORE"
    echo "  + $entry"
  fi
}

# Ensure .gitignore exists
[ -f "$GITIGNORE" ] || touch "$GITIGNORE"

echo "Actualizando .gitignore..."
printf "\n# Forge — herramienta local, no versionada\n" >> "$GITIGNORE"
gitignore_add ".forge/"

# Add adapter entries for each detected tool
for tool in "${DETECTED[@]}"; do
  case "$tool" in
    claude)   gitignore_add ".claude/" ;;
    cursor)   gitignore_add ".cursor/" ;;
    copilot)  gitignore_add ".github/copilot-instructions.md" ;;
    windsurf) gitignore_add ".windsurfrules" ;;
    gemini)   gitignore_add ".gemini/" ;;
  esac
done
echo ""

# 8. Generate adapters
echo "Generando adaptadores..."
for tool in "${DETECTED[@]}"; do
  case "$tool" in
    claude)   generate_claude_adapter ;;
    cursor)   generate_cursor_adapter ;;
    copilot)  generate_copilot_adapter ;;
    windsurf) generate_windsurf_adapter ;;
    gemini)   generate_gemini_adapter ;;
  esac
done

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "🔥 Forge v0.4 configurado en este proyecto."
echo ""
echo "Próximos pasos:"
echo "  1. Editá .forge/config.yaml con tu stack"
echo "  2. Abrí tu herramienta de IA en este proyecto"
echo "  3. Ejecutá: forge new \"nombre de tu primera feature\""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
