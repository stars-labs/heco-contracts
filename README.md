# huobi-eco-contracts

## Prepare

Install dependency:

```bash
npm install
```

## unit test

Generate test contract files:

```bash
node generate-mock-contracts.js
```

Start ganache:

```bash
ganache-cli -e 20000000000 -a 100 -l 8000000 -g 0
```

Test:

```bash
truffle test
```
