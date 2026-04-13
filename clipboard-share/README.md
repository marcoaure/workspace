# Clipboard Share

Compartilha clipboard (texto + arquivos) entre Mac e Windows via rede local.

## Setup

### Mac

```bash
cd ~/Projects/personal/workspace/clipboard-share
./setup.sh
```

### Windows

```powershell
cd ~\workspace\clipboard-share
.\setup.ps1
```

O setup instala dependências, configura autostart e registra hotkeys.

## Uso

| Ação | Mac | Windows |
|------|-----|---------|
| Enviar clipboard pro outro PC | **Cmd+Shift+C** | **Ctrl+Shift+C** |
| Colar | Cmd+V (normal) | Ctrl+V (normal) |

O server roda em background e injeta automaticamente no clipboard ao receber.

## Config

Edite `config.json` em cada máquina:

```json
{
  "port": 9876,
  "remote_host": "HOSTNAME-DO-OUTRO-PC.local",
  "temp_dir": "clipboard-share-temp",
  "max_file_size_mb": 50
}
```

## Troubleshooting

- **"Outro PC não encontrado"**: Verifique se o server está rodando (`curl http://HOSTNAME.local:9876/health`)
- **mDNS não resolve**: Use IP direto no `remote_host` (ex: `192.168.1.100`)
- **Windows mDNS**: Precisa do Bonjour service (vem com iTunes/iCloud)
