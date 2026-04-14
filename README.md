# TG WS Proxy

Локальный MTProto-прокси для Telegram Desktop, который перенаправляет трафик через WebSocket-соединения. Проект работает в консольном режиме: без tray, без GUI и без desktop-зависимостей.

## Что умеет

- поднимает локальный MTProto-прокси на `host:port`
- проксирует трафик Telegram Desktop через WebSocket к Telegram DC
- при проблемах с WebSocket может переключаться на CfProxy или прямой TCP fallback
- поддерживает Fake TLS маскировку для `ee`-секрета
- умеет работать за reverse proxy с `PROXY protocol`

## Как это работает

```text
Telegram Desktop → MTProto Proxy (127.0.0.1:1443) → WebSocket → Telegram DC
```

Прокси принимает локальное MTProto-подключение, определяет нужный DC из obfuscation init-пакета и открывает соответствующее outbound WebSocket-соединение. Если основной WebSocket-путь не срабатывает, он может перейти на альтернативный маршрут.

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

## Базовый запуск

```bash
tg-ws-proxy
```

Примеры:

```bash
# другой порт и дополнительные DC
tg-ws-proxy --port 9050 --dc-ip 1:149.154.175.205 --dc-ip 2:149.154.167.220

# подробное логирование
tg-ws-proxy -v

# Fake TLS маскировка
tg-ws-proxy --fake-tls-domain example.com

# свой Cloudflare-домен для fallback
tg-ws-proxy --cfproxy-domain example.com
```

## Основные аргументы

| Аргумент | По умолчанию | Описание |
|---|---|---|
| `--port` | `1443` | Порт прокси |
| `--host` | `127.0.0.1` | Хост прокси |
| `--secret` | `random` | 32-символьный hex secret для клиентов |
| `--dc-ip` | `2:149.154.167.220`, `4:149.154.167.220` | Целевой IP для DC, можно указывать несколько раз |
| `--no-cfproxy` | `false` | Отключить Cloudflare fallback |
| `--cfproxy-domain` | | Указать свой домен для CfProxy fallback |
| `--cfproxy-priority` | `true` | Пробовать CfProxy перед прямым TCP |
| `--fake-tls-domain` | | Включить Fake TLS маскировку с указанным SNI-доменом |
| `--proxy-protocol` | выкл. | Принимать PROXY protocol v1 |
| `--buf-kb` | `256` | Размер буфера в КБ |
| `--pool-size` | `4` | Размер пула заготовленных WS-соединений |
| `--log-file` | выкл. | Путь к файлу логов |
| `--log-max-mb` | `5` | Максимальный размер файла логов в МБ |
| `--log-backups` | `0` | Количество сохранённых файлов после ротации |
| `-v`, `--verbose` | выкл. | Подробное логирование |

## Настройка Telegram Desktop

1. Откройте Telegram → Настройки → Продвинутые настройки → Тип подключения → Прокси
2. Добавьте прокси типа `MTProto`
3. Укажите:
   - Server: `127.0.0.1` или ваш `--host`
   - Port: `1443` или ваш `--port`
   - Secret: значение из `--secret` или из логов при автогенерации

## CfProxy

CfProxy нужен как fallback для случаев, когда обычный WebSocket-маршрут до Telegram DC недоступен. В проекте есть домены по умолчанию, но надёжнее использовать свой домен: так вы не зависите от общего публичного пула и его лимитов.

### Когда стоит использовать свой домен

- если публичные CfProxy-домены работают нестабильно
- если нужен более предсказуемый fallback
- если вы хотите контролировать TLS и DNS на своей стороне

### Быстрая настройка своего домена

1. Добавьте домен в Cloudflare
2. В `SSL/TLS` → `Overview` выставьте режим `Flexible`
3. В `DNS` создайте записи:
   - `kws1` → `149.154.175.50`
   - `kws2` → `149.154.167.51`
   - `kws3` → `149.154.175.100`
   - `kws4` → `149.154.167.91`
   - `kws5` → `149.154.171.5`
   - `kws203` → `91.105.192.100`
4. Если Cloudflare-подсеть у вас блокируется, добавьте домен в локальный инструмент обхода блокировок
5. Запустите прокси с `--cfproxy-domain <ваш_домен>`

## Fake TLS

Если нужен `ee`-secret режим, используйте `--fake-tls-domain`. Этот домен должен указывать на тот же IP, где слушает прокси.

Пример запуска за nginx:

```bash
python -m proxy.tg_ws_proxy \
  --port 8446 \
  --host 127.0.0.1 \
  --fake-tls-domain example.com \
  --proxy-protocol \
  --secret <32-hex-chars>
```

Пример upstream-конфигурации `nginx` (`stream`):

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

## Ограничения и заметки по безопасности

- это специализированный обходной прокси, а не универсальный secure tunnel
- fallback-маршруты через CfProxy добавляют внешнюю доверительную поверхность
- при использовании своего домена поведение предсказуемее, чем на публичных fallback-доменах
- секрет прокси даёт доступ к подключению, поэтому хранить его нужно аккуратно

## Автоматическая сборка

GitHub Actions в этом форке собирает только консольные Python-артефакты и не включает desktop bundle.

## Лицензия

[MIT License](LICENSE)
