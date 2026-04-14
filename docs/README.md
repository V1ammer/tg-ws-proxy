# TG WS Proxy

**Локальный MTProto-прокси** для Telegram Desktop, который перенаправляет трафик через WebSocket-соединения. Репозиторий теперь поддерживает только **консольный режим**: без tray, без GUI и без desktop-зависимостей вроде `libxkcb`.

## Как это работает

```text
Telegram Desktop → MTProto Proxy (127.0.0.1:1443) → WebSocket → Telegram DC
```

1. Приложение поднимает MTProto-прокси на указанном `host:port`
2. Перехватывает подключения к IP-адресам Telegram
3. Извлекает DC ID из MTProto obfuscation init-пакета
4. Устанавливает WebSocket (TLS) соединение к соответствующему DC через домены Telegram
5. Если WS недоступен — автоматически переключается на CfProxy / прямое TCP-соединение

## Быстрый старт

### Установка из исходников

```bash
pip install .
tg-ws-proxy --help
```

### Установка через Nix flakes

```bash
nix profile install .#tg-ws-proxy
tg-ws-proxy --help
```

Локальный запуск без установки:

```bash
nix run .#tg-ws-proxy -- --help
```

## Запуск

```bash
tg-ws-proxy [--port PORT] [--host HOST] [--dc-ip DC:IP ...] [-v]
```

**Аргументы:**

| Аргумент | По умолчанию | Описание |
|---|---|---|
| `--port` | `1443` | Порт прокси |
| `--host` | `127.0.0.1` | Хост прокси |
| `--secret` | `random` | 32 hex chars secret для авторизации клиентов |
| `--dc-ip` | `2:149.154.167.220`, `4:149.154.167.220` | Целевой IP для DC (можно указать несколько раз) |
| `--no-cfproxy` | `false` | Отключить попытку проксирования через Cloudflare |
| `--cfproxy-domain` | | Указать свой домен для проксирования через Cloudflare |
| `--cfproxy-priority` | `true` | Пробовать Cloudflare перед прямым TCP-подключением |
| `--fake-tls-domain` | | Включить Fake TLS (ee-secret) маскировку с указанным SNI-доменом |
| `--proxy-protocol` | выкл. | Принимать HAProxy PROXY protocol v1 |
| `--buf-kb` | `256` | Размер буфера в КБ |
| `--pool-size` | `4` | Количество заготовленных соединений на каждый DC |
| `--log-file` | выкл. | Путь до файла, в который сохранять логи |
| `--log-max-mb` | `5` | Максимальный размер файла логов в МБ |
| `--log-backups` | `0` | Количество сохранений логов после ротации |
| `-v`, `--verbose` | выкл. | Подробное логирование (DEBUG) |

**Примеры:**

```bash
# Стандартный запуск
tg-ws-proxy

# Другой порт и дополнительные DC
tg-ws-proxy --port 9050 --dc-ip 1:149.154.175.205 --dc-ip 2:149.154.167.220

# С подробным логированием
tg-ws-proxy -v

# Fake TLS маскировка (ee-secret)
tg-ws-proxy --fake-tls-domain example.com
```

## Настройка Telegram Desktop

1. Telegram → **Настройки** → **Продвинутые настройки** → **Тип подключения** → **Прокси**
2. Добавить прокси:
   - **Тип:** MTProto
   - **Сервер:** `127.0.0.1` (или переопределённый вами)
   - **Порт:** `1443` (или переопределённый вами)
   - **Secret:** тот, который вы передали через `--secret` или увидели в логах при автогенерации

## Fake TLS + nginx upstream

### Домен (`--fake-tls-domain`) должен указывать на тот же IP, на котором стоит прокси

**Пример `nginx.conf` (stream):**

```nginx
upstream mtproto {
    server 127.0.0.1:8446;
}

map $ssl_preread_server_name $sni_name {
    hostnames;
    example.com mtproto;
}

server {
    proxy_protocol on;
    set_real_ip_from unix:;
    listen          443;
    proxy_pass      $sni_name;
    ssl_preread     on;
}
```

**Запуск прокси за nginx:**

```bash
python -m proxy.tg_ws_proxy \
  --port 8446 \
  --host 127.0.0.1 \
  --fake-tls-domain example.com \
  --proxy-protocol \
  --secret <32-hex-chars>
```

Ссылка для подключения будет в формате `ee`-секрета:

```text
tg://proxy?server=your.domain.com&port=443&secret=ee<secret><domain_hex>
```

## Автоматическая сборка

GitHub Actions в этом форке собирает только консольные Python-артефакты и не включает PyInstaller или desktop bundle.

## Лицензия

[MIT License](LICENSE)
