# Workspace

Configuração cross-platform da estação de trabalho do Marco. Tudo que precisa para bootstrapar ou replicar o setup em Windows e macOS.

## Máquinas

| Máquina | OS | Uso |
|---|---|---|
| Desktop | Windows 11 | Dev principal, GPU AMD RX 6900 XT |
| MacBook | macOS (Apple Silicon) | Dev secundário / mobile |

## Periféricos Compartilhados

| Dispositivo | Modelo | Switch |
|---|---|---|
| Monitor 1 | Alienware AW2725DF 27" QD-OLED | 2 cabos DP (um por PC) |
| Monitor 2 | Samsung UR550 28" 4K | DP (Win) + HDMI (Mac) |
| Teclado | Logitech MX Keys | Easy Switch (canal 1=Win, 2=Mac) |
| Mouse | Logitech MX Anywhere 3S | Easy Switch (canal 1=Win, 2=Mac) |

## Módulos

### [`switch-station/`](switch-station/)
KVM via software — troca os 2 monitores entre Windows e Mac com um único comando usando DDC/CI. Zero dependências externas no Windows (usa `dxva2.dll`), `m1ddc` + `BetterDisplay` no Mac.

```powershell
# No Windows
mac           # troca tudo pro Mac
windows       # volta pro Windows
```

```bash
# No Mac
windows       # troca tudo pro Windows (ou ⌃⌥W)
mac-fix       # volta pro Mac (ou ⌃⌥M)
```

### [`clipboard-share/`](clipboard-share/)
Clipboard compartilhado entre Mac e Windows via rede local. Texto e arquivos até 50MB.

```bash
# No Mac — enviar pro Windows
Cmd+Shift+C

# No Windows — enviar pro Mac
Ctrl+Shift+C

# Colar: Cmd+V / Ctrl+V normal
```

### `dotfiles/` *(em breve)*
Configurações de shell, git, editor. Symlink para os locais corretos em cada OS.

### `scripts/` *(em breve)*
Automações avulsas — cleanup, backup, maintenance.

### `setup/` *(em breve)*
Bootstrap scripts por OS — instala ferramentas, configura sistema.

## Estrutura

```
workspace/
├── switch-station/        # DDC/CI monitor switch (Win ↔ Mac)
│   ├── lib/               # Módulos PowerShell (DDC/CI, DisplayControl)
│   ├── mac/               # Scripts Mac (m1ddc)
│   ├── config.json        # Mapeamento de inputs por monitor
│   ├── discover.ps1       # Descobre monitores DDC/CI
│   ├── setup.ps1          # Registra aliases no PowerShell
│   ├── switch-to-mac.ps1  # Script principal de troca
│   └── README.md          # Docs completos + valores DDC/CI
├── dotfiles/              # Configs de shell/editor (TODO)
├── scripts/               # Automações (TODO)
├── setup/                 # Bootstrap por OS (TODO)
└── README.md              # ← este arquivo
```

## Convenções

- **Cross-platform:** Scripts Windows em PowerShell (`.ps1`), Mac/Linux em Bash (`.sh`)
- **Cada módulo é independente** — tem seu próprio README, setup, e pode ser usado sozinho
- **`.instructions.md`** em cada módulo — contexto para IA (Claude/Copilot) trabalhar no código
- **Zero dependências externas quando possível** — preferir APIs nativas do OS
