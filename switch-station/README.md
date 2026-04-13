# Switch Station

Troca toda a estação de trabalho (2 monitores + periféricos Logitech) entre Windows PC e MacBook com um único comando.

Usa o protocolo **DDC/CI** para enviar comandos de troca de input diretamente aos monitores via cabo, sem ferramentas externas no Windows (usa a API nativa `dxva2.dll`). No Mac usa [`m1ddc`](https://github.com/waydabber/m1ddc) para monitores via DisplayPort e [BetterDisplay](https://betterdisplay.pro/) para monitores via HDMI (m1ddc não suporta DDC/CI via HDMI no Apple Silicon).

## Hardware

| Componente | Modelo | Conexão Windows | Conexão Mac |
|---|---|---|---|
| Monitor 1 | Alienware AW2725DF 27" QD-OLED | DisplayPort-1 | DisplayPort-2 |
| Monitor 2 | Samsung UR550 (LU28R55) 28" 4K | DisplayPort | HDMI |
| Teclado | Logitech MX Keys | Bluetooth (canal 1) | Bluetooth (canal 2) |
| Mouse | Logitech MX Anywhere 3S | Bluetooth (canal 1) | Bluetooth (canal 2) |
| GPU (Windows) | AMD Radeon RX 6900 XT | — | — |

## Uso Rápido

### No Windows — mudar pro Mac

```powershell
mac
```

### No Windows — voltar pro Windows (emergência)

```powershell
windows
```

### No Mac — mudar pro Windows

```bash
windows          # terminal
# ou ⌃⌥W        # hotkey global (qualquer app)
```

### No Mac — voltar pro Mac (emergência)

```bash
mac-fix          # terminal
# ou ⌃⌥M        # hotkey global (qualquer app)
```

> **Nota:** Após trocar os monitores, pressione o botão Easy Switch no teclado e no mouse para trocar o canal Bluetooth. Isso não é automatizável.

## Estrutura do Projeto

```
switch-station/
├── config.json              # Source of truth: monitores + periféricos (Win + Mac)
├── discover.ps1             # Descobre monitores e valores DDC/CI (Windows)
├── setup.ps1                # Registra aliases 'mac' e 'windows' no PowerShell
├── switch-to-mac.ps1        # Script principal (Windows): periféricos + monitores
├── switch-to-mac.bat        # Launcher .bat (double-click / taskbar)
├── switch-to-windows.bat    # Launcher .bat emergência (volta pro Windows)
├── lib/
│   ├── DDC.psm1             # Módulo DDC/CI via dxva2.dll (zero dependências)
│   ├── HIDSwitch.psm1       # Módulo HID++ Change Host via Windows HID API
│   └── DisplayControl.psm1  # Módulo attach/detach de displays (auxiliar)
└── mac/
    ├── discover.sh           # Descobre monitores DDC/CI no Mac
    ├── hid_switch            # Binário Swift/IOKit pra HID++ Change Host (macOS)
    ├── hid_switch.swift      # Source do hid_switch
    ├── hidapitester          # Ferramenta HID genérica (fallback)
    ├── setup.sh              # Setup completo: instala deps, aliases, hotkeys
    └── switch-to-windows.sh  # Script principal (Mac): periféricos + monitores
```

## Setup

### Windows (já feito)

```powershell
cd ~\switch-station
.\setup.ps1
```

Isso registra as funções `mac` e `windows` no `$PROFILE` do PowerShell. Reabra o terminal para usar.

### Mac (primeira vez)

```bash
cd ~/Projects/personal/workspace/switch-station   # ou onde clonou
./mac/setup.sh
```

O `setup.sh` faz tudo automaticamente:
1. Instala dependências via Homebrew (m1ddc, jq, BetterDisplay, Hammerspoon)
2. Registra aliases `windows` e `mac-fix` no zsh/bash
3. Configura hotkeys globais via Hammerspoon (⌃⌥W / ⌃⌥M)

**Único passo manual:** na primeira vez, habilitar Hammerspoon em **System Settings > Privacy & Security > Accessibility**.

**Dependências:**
- **m1ddc** — DDC/CI para monitores via DisplayPort
- **BetterDisplay** — DDC/CI para monitores via HDMI (m1ddc não suporta HDMI no Apple Silicon)
- **Hammerspoon** — hotkeys globais (⌃⌥W / ⌃⌥M)
- **jq** — leitura do config.json

Num Mac zerado, só precisa ter Homebrew instalado antes.

## Valores DDC/CI Descobertos

### VCP Code 0x60 (Input Source Select)

Este é o código VCP do protocolo DDC/CI que controla a troca de input do monitor.

### Alienware AW2725DF

| Input | Valor VCP | Hex | Notas |
|---|---|---|---|
| DisplayPort-1 (Windows) | **15** | `0x0F` | Padrão MCCS |
| DisplayPort-2 (Mac) | **19** | `0x13` | Reporta como `3859` (0xF13) no read — ver quirks |

**Quirk:** O Alienware reporta valores de 2 bytes no `GetVCPFeatureAndVCPFeatureReply`. O valor real é o **low byte**:
- Read retorna `3855` → `0x0F0F` → low byte = `0x0F` = 15 (DP-1)
- Read retorna `3859` → `0x0F13` → low byte = `0x13` = 19 (DP-2)
- Para escrita, basta enviar o low byte (15 ou 19).

### Samsung UR550 (LU28R55)

| Input | Valor VCP | Hex | Notas |
|---|---|---|---|
| DisplayPort (Windows) | **15** | `0x0F` | Padrão MCCS |
| HDMI (Mac) | **5** | `0x05` | **NÃO-PADRÃO** — ver seção abaixo |

**⚠️ ATENÇÃO — Samsung usa valores não-padrão!**

O padrão MCCS/VESA define HDMI-1 como `17` (0x11) e HDMI-2 como `18` (0x12). O Samsung UR550 **ignora esses valores** e usa um mapeamento próprio:

| Input | Valor Samsung | Valor Padrão MCCS |
|---|---|---|
| HDMI-1 | **5** (0x05) | 17 (0x11) |
| HDMI-2 | **6** (0x06) | 18 (0x12) |
| DisplayPort | **15** (0x0F) | 15 (0x0F) |

Isso foi descoberto via:
1. [ddcutil issue #343](https://github.com/rockowitz/ddcutil/issues/343) — Samsung monitors use non-standard input values
2. [ddcutil issue #185](https://github.com/rockowitz/ddcutil/issues/185) — Samsung C27HG70 same problem
3. Teste de brute-force: valores 1–20, apenas `5` funcionou para HDMI

**Quirk adicional:** O Samsung reporta valores inconsistentes no read do VCP 0x60. Pode retornar `0`, `5`, `6`, ou `15` para o mesmo input DP. As **escritas funcionam normalmente** apesar dos reads serem inconsistentes.

### Tabela de Referência — Valores MCCS Padrão

Para referência ao adicionar novos monitores:

| Input | Valor MCCS | Hex |
|---|---|---|
| VGA-1 | 1 | 0x01 |
| VGA-2 | 2 | 0x02 |
| DVI-1 | 3 | 0x03 |
| DVI-2 | 4 | 0x04 |
| Composite-1 | 5 | 0x05 |
| Composite-2 | 6 | 0x06 |
| S-Video-1 | 7 | 0x07 |
| S-Video-2 | 8 | 0x08 |
| Component-1 | 12 | 0x0C |
| Component-2 | 13 | 0x0D |
| DisplayPort-1 | 15 | 0x0F |
| DisplayPort-2 | 16 | 0x10 |
| HDMI-1 | 17 | 0x11 |
| HDMI-2 | 18 | 0x12 |

> **Importante:** Muitos monitores (especialmente Samsung, LG, e alguns Dell) usam valores próprios que não seguem a tabela acima. Sempre rodar `discover.ps1` / `discover.sh` e testar com brute-force se os valores padrão não funcionarem.

## Protocolo DDC/CI — Como Funciona

**DDC/CI** (Display Data Channel / Command Interface) é um protocolo que permite ao computador enviar comandos ao monitor pelo mesmo cabo de vídeo (DP, HDMI, DVI, VGA). Não precisa de cabo extra.

### Arquitetura

```
┌──────────────┐     VCP 0x60 = 15     ┌─────────────────┐
│  Windows PC  │ ◄──── DP Cable ─────► │   Monitor OSD   │
│  (dxva2.dll) │     DDC/CI write      │  Input: DP-1 ✓  │
└──────────────┘                       └─────────────────┘

┌──────────────┐     VCP 0x60 = 19     ┌─────────────────┐
│  Windows PC  │ ◄──── DP Cable ─────► │   Monitor OSD   │
│  (dxva2.dll) │     DDC/CI write      │  Input: DP-2 ✓  │
└──────────────┘                       │  (mostra o Mac)  │
                                       └─────────────────┘
```

### VCP Codes Usados

| Código | Nome | Tipo | Descrição |
|---|---|---|---|
| `0x60` | Input Source | Read/Write | Troca o input ativo do monitor |
| `0x10` | Brightness | Read/Write | Brilho (usado para testar DDC/CI) |

### Fluxo do Switch

1. **PowerShell** carrega `DDC.psm1` que faz P/Invoke para `dxva2.dll`
2. `EnumDisplayMonitors` → lista monitores lógicos do Windows
3. `GetPhysicalMonitorsFromHMONITOR` → obtém handles DDC/CI dos monitores físicos
4. `SetVCPFeature(handle, 0x60, valor)` → envia comando de troca de input
5. Monitor recebe o comando e troca o input internamente
6. O cabo do outro PC (Mac) passa a exibir sinal
7. O Windows **perde** o monitor (display desconectado do ponto de vista do OS)

### Por que enviar o comando do Windows funciona mesmo mudando pro Mac?

O comando DDC/CI é enviado pelo cabo de vídeo que conecta o Windows ao monitor. O monitor recebe o comando, troca o input, e passa a mostrar o sinal do Mac. O Windows não precisa "saber" sobre o Mac — ele só diz ao monitor "mude para o input X".

## config.json

Fonte de verdade única para **ambos** os lados (Windows e Mac).

```json
{
  "monitors": [
    {
      "name": "Alienware AW2725DF",
      "match_windows": "Alienware|AW2725",
      "match_mac": "AW2725",
      "mac_display": 1,
      "windows_input": 15,
      "mac_input": 19
    },
    {
      "name": "Samsung UR550",
      "match_windows": "Generic PnP",
      "match_mac": "LU28R55",
      "mac_display": 2,
      "windows_input": 15,
      "mac_input": 5
    }
  ]
}
```

| Campo | Descrição |
|---|---|
| `match_windows` | Regex aplicado no `szPhysicalMonitorDescription` retornado pelo Windows. Samsung aparece como "Generic PnP Monitor". |
| `match_mac` | Texto para identificar o monitor no `m1ddc display list` (ex: `AW2725`, `LU28R55`). |
| `mac_display` | Número do display no m1ddc (1-based). Rode `./mac/discover.sh` para verificar. |
| `mac_tool` | Ferramenta no Mac: `m1ddc` (monitores via DP) ou `betterdisplay` (monitores via HDMI). |
| `windows_input` / `mac_input` | Valores VCP 0x60 para cada input. |

### Periféricos

| Campo | Descrição |
|---|---|
| `vid` / `pid` | Vendor/Product ID do dispositivo Bluetooth (ex: `046D`/`B35B` para MX Keys). |
| `change_host_feature_index` | Feature index HID++ do Change Host (descoberto via protocol query). |
| `mac_hid_tool` | `hid_switch` (Swift/IOKit). |
| `windows_channel` / `mac_channel` | Índice do canal (0-based: 0=canal 1, 1=canal 2, 2=canal 3). |

## Troubleshooting

### Monitor não troca (pisca e volta)

O valor de input está errado para esse monitor. Rode `discover.ps1` e confira. Se necessário, teste valores com brute-force:

```powershell
Import-Module .\lib\DDC.psm1 -Force
$m = [DDCMonitor]::GetAll()
# Testar valor X no monitor 0:
[DDCMonitor]::SetVCP($m[0].hPhysicalMonitor, 0x60, [uint32]X)
```

### Monitor vai pra tela preta (limbo)

O valor aponta para um input sem cabo conectado. O monitor pode ficar em loop procurando sinal. Soluções:
1. Pressionar botões no monitor para voltar ao input correto via OSD
2. Rodar `switch-to-mac.ps1 -Reverse` se ainda tiver um monitor funcionando
3. Verificar se o cabo do Mac está bem conectado naquele input

### DDC/CI não encontra monitor

1. Verificar se DDC/CI está ativo no menu OSD do monitor
2. Alguns monitores desabilitam DDC/CI com configurações de energia
3. Cabos adaptadores (HDMI→DP, USB-C→DP) podem não passar DDC/CI
4. Após detach/reattach de display, os handles DDC/CI podem ficar inválidos — reabrir o script

### Samsung leitura retorna valor errado

Normal. O Samsung UR550 reporta valores inconsistentes no read do VCP 0x60. As escritas funcionam. Não confie no `GetInput()` para Samsung — use como referência apenas.

## Histórico de Descobrimento

### Tentativas que falharam no Samsung

| Valor | Resultado | Origem |
|---|---|---|
| 17 (0x11) | Piscou e voltou | Padrão MCCS HDMI-1 |
| 18 (0x12) | Piscou e voltou | Padrão MCCS HDMI-2 |
| 11 | Piscou e voltou | Tentativa |
| 12 | Piscou e voltou | Tentativa |
| 19 | Piscou e voltou | Script antigo (era pro Alienware) |
| 1–4, 6–20 (exceto 5) | Piscou e voltou ou sem efeito | Brute-force |
| **5** | **✅ Funcionou!** | ddcutil issues + brute-force |

### Tentativas que falharam no Alienware

| Valor | Resultado | Causa |
|---|---|---|
| 17 (0x11) | Tela preta | Cabo Mac não estava no HDMI (estava no DP-2) |
| 19 após cabo solto | Tela preta | Cabo Mac desconectado do DP-2 |
| **19 após reconectar** | **✅ Funcionou!** | Cabo reconectado ao DP-2 |

### Ferramentas testadas e descartadas

| Ferramenta | Motivo do descarte |
|---|---|
| ControlMyMonitor (NirSoft) | Ficava travando/timeout em todos os comandos |
| Display detach/reattach | Perdia os handles DDC/CI e não ajudava no Samsung |
| Auto Source Switch (Samsung) | Não resolveu, pois o valor do input é que estava errado |

## Licença

Uso pessoal. Adapte para seu setup alterando `config.json`.
