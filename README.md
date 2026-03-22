# Lottery (Raffle)

Контракт лотереи на Solidity: игроки платят входной взнос, по истечении интервала времени через **Chainlink Automation** (`checkUpkeep` / `performUpkeep`) запрашивается случайность **Chainlink VRF v2.5**, выбирается победитель, приз переводится на его адрес.

- **Сеть по умолчанию в скриптах:** Sepolia  
- **Стек:** [Foundry](https://book.getfoundry.sh/), Chainlink contracts (через `lib/chainlink`)

## Требования

- [Foundry](https://book.getfoundry.sh/getting-started/installation) (`forge`, `cast`, `anvil`)

## Установка

```bash
git clone https://github.com/Myth1call/lottery-Raffle
cd lottery
git submodule update --init --recursive
```

Или зависимости из `Makefile`:

```bash
make install
```

Сборка:

```bash
make build
# или
forge build
```

## Переменные окружения

Скопируйте пример и заполните значения:

```bash
cp .env.example .env
```

| Переменная | Назначение |
|------------|------------|
| `SEPOLIA_RPC_URL` | RPC Sepolia (Alchemy, Infura и т.д.) |
| `ETHERSCAN_API_KEY` | Ключ Etherscan для верификации контракта |

Для деплоя через `Makefile` используется **`--account my-sepolia`** (Foundry keystore). Импорт ключа:

```bash
cast wallet import my-sepolia --private-key "$PRIVATE_KEY"
```

Альтернатива — вызывать `forge script` вручную с `--private-key` (ключ не коммитьте).

## Конфигурация сети (`HelperConfig`)

Файл: `script/HelperConfig.s.sol`.

- **Sepolia:** задайте `subscriptionId` и `account` (адрес владельца VRF-подписки и кошелька для скриптов).  
  Если `subscriptionId == 0`, `DeployRaffle` попытается создать подписку и профондить её (нужен валидный `account` и LINK на Sepolia).
- **Локально (Anvil, chain id 31337):** поднимается мок VRF и тестовый LINK; отдельная настройка не нужна.

Адрес LINK на Sepolia в конфиге уже задан (официальный тестовый LINK).

## Тесты

```bash
make test
# или
forge test
```

Рекомендуется гонять **без** `--fork-url`: юнит-тесты рассчитаны на локальный мок VRF. С форком Sepolia часть сценариев (ручной `fulfillRandomWords`, точный баланс контракта) может вести себя иначе.

```bash
forge test -vvv
```

## Деплой на Sepolia

Убедитесь, что в `HelperConfig` заполнены `subscriptionId` / `account` (или `subscriptionId = 0` и корректный `account` для автосоздания подписки), в `.env` заданы `SEPOLIA_RPC_URL` и `ETHERSCAN_API_KEY`, keystore содержит `my-sepolia`.

```bash
make deploy-sepolia
```

Эквивалент вручную см. в `Makefile` (`forge script script/DeployRaffle.s.sol:DeployRaffle ...`).

## Скрипты взаимодействия

| Скрипт | Контракт в `Interactions.s.sol` | Назначение |
|--------|-----------------------------------|------------|
| `CreateSubscription` | `CreateSubscription` | Создать VRF-подписку |
| `FundSubscription` | `FundSubscription` | Пополнить подписку (на Sepolia — через LINK `transferAndCall`) |
| `AddConsumer` | `AddConsumer` | Добавить consumer (контракт Raffle) в подписку |

Запуск (пример):

```bash
forge script script/Interactions.s.sol:CreateSubscription --rpc-url "$SEPOLIA_RPC_URL" --account my-sepolia --broadcast -vvvv
```

## Структура проекта

```
src/           — контракт Raffle
script/        — деплой, HelperConfig, Interactions
test/unit/     — юнит-тесты
test/mocks/    — моки (например LinkToken)
lib/           — forge-std, chainlink, solmate, foundry-devops
```

## CI

В `.github/workflows/test.yml` выполняются `forge fmt --check`, `forge build`, `forge test`.

## Лицензия

См. SPDX-заголовки в исходниках (MIT).
