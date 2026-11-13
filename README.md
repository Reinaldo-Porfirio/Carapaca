# Carcaça — Circuito Fornalha

Jogo 3D de combate em arena entre carcaças blindadas montadas peça por peça. Feito em **Godot 4.6** (GDScript), com versões para **Windows, Linux, macOS e navegador**.

## Jogar

- **No navegador:** https://reinaldo-porfirio.github.io/carapaca/
- **No computador:** baixe o arquivo do seu sistema na página [Releases](https://github.com/Reinaldo-Porfirio/carapaca/releases) e extraia.
  - **Windows:** abra `Carcaca.exe`. Se aparecer "O Windows protegeu o computador", clique em *Mais informações → Executar assim mesmo* (o executável não tem assinatura paga).
  - **Linux:** `chmod +x Carcaca.x86_64` e execute.
  - **macOS:** extraia o `.zip`, clique com o botão direito em `Carcaca.app` → *Abrir* (o macOS bloqueia apps sem assinatura da Apple na primeira vez).

Roda em placas integradas antigas: sem Vulkan, o jogo muda sozinho para o modo de compatibilidade (OpenGL).

## Controles

| Tecla | Ação |
|---|---|
| W A S D | mover |
| Mouse | mirar |
| Espaço | saltar · segurar para subir |
| Shift | impulso rápido |
| Ctrl ou C | sobreimpulso |
| Botões do mouse | armas das mãos |
| Q / E | unidades dorsais |
| R | ombros |
| F | utilitário |
| G | kit de reparo |
| T / Tab | trava fixa / trocar alvo |
| Esc | pausa |

Controle de videogame também funciona.

## Estrutura do repositório

- `game/` — projeto Godot (abra `game/project.godot` no editor Godot 4.6).
  - `scripts/` — lógica do jogo, modelos procedurais das carcaças, arenas, HUD e menus.
  - `shaders/` — materiais procedurais (pintura com desgaste, cenário, céu, partículas).
  - `data.json` — catálogo de peças, rivais, arenas e modificadores.
- `web-v1/` — versão 1.0 original em JavaScript/three.js (preservada; tag `v1.0`).

## Compilar

Com o Godot 4.6 e os modelos de exportação instalados:

    godot --headless --path game --export-release "Windows" ../build/windows/Carcaca.exe
    godot --headless --path game --export-release "Linux" ../build/linux/Carcaca.x86_64
    godot --headless --path game --export-release "macOS" ../build/macos/Carcaca.zip
    godot --headless --path game --export-release "Web" ../build/web/index.html

## Créditos

Fontes Saira Condensed e IBM Plex Mono sob a SIL Open Font License (arquivos em `game/fonts/`). Todo o resto — modelos, texturas, sons e música — é gerado por código.
