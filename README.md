# Dual-clock FIFO

Параметризуемый асинхронный FIFO на Verilog. Указатели записи и чтения передаются между независимыми тактовыми доменами в коде Грея через двухтактные синхронизаторы.

## Структура

- `rtl/sem5_dclkfifo.v` — модуль FIFO;
- `tb/tb_sem5_dclkfifo.v` — самопроверяющийся testbench;
- `Makefile` — цели для проверки и моделирования.

## Запуск

Требуются `make`, Icarus Verilog и Verilator. GTKWave нужен только для просмотра временных диаграмм.

```sh
make          # lint и моделирование
make sim      # моделирование через Icarus Verilog
make wave     # моделирование и открытие wave.vcd
make clean    # удаление результатов сборки
```

Успешный тест завершается сообщением:

```text
PASS: all asynchronous FIFO tests completed successfully
```
