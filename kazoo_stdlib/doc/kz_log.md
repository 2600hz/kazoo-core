# Table printing

`kz_log:print_table/1` and `kz_log:print_table/2` allow you to provide a list of row data (itself a list of terms) and output a fixed-width table.

For example:

```
> kz_log:print_table([[<<"a">>, <<"B">>, <<"cc">>], [1, 3, 5]]).
|a|B|cc|
|1|3| 5|
```

Cell size will adjust based on the terms in the same column:

```
> kz_log:print_table([[<<"a">>, <<"B">>, <<"ccc">>], [1, 3, 5], [$a, 17, self()]]).
| a| B|         ccc|
| 1| 3|           5|
|97|17|<0.464543.0>|
```

## Table options

### Cell Divider

By default, `|` is used to divide the cells. Change it using `cell_divider` in the `Options`:

```
> kz_log:print_table([[<<"a">>, <<"B">>, <<"ccc">>], [1, 3, 5], [$a, 17, self()]], #{cell_divider => $%}).
% a% B%         ccc%
% 1% 3%           5%
%97%17%<0.464543.0>%
```

### Header Divider

If you want to treat your first row as a header, and put a header divider between the first row and the data rows:

```
> kz_log:print_table([[<<"a">>, <<"B">>, <<"ccc">>], [1, 3, 5], [$a, 17, self()]], #{header_divider => $=}).
| a| B|         ccc|
|==|==|============|
| 1| 3|           5|
|97|17|<0.464543.0>|
```

### Per-column customization

It is possible to pre-configure how you want a column to display

- `justification`: `'left' | 'right'`: defaults to right-justified
- `pad_char`: `char()`: padding character to use to fill the cell, if needed, default: `$\s`
- `control_sequence_modifier`: `'unicode' | 'unprintable'`: if you know your cell data will contain unicode or not search for printable characters
- `control_sequence`: `$s | $p`: how to print the data, defaults to `$s` (conversion to binary is attempted on the cell's value. `$p` to use Erlang's pretty-printing of the cell value

Some examples:

Here, the first two cells are left-justified and the third cell is undefined so defaults are used.

```
kz_log:print_table([[<<"a">>, <<"B">>, <<"ccc">>], [1, 3, 5], [$a, 17, self()]]
                   ,#{header_divider => $=, row_spacing => [#{justification => left}, #{justification => left}]}
                   ).
|a |B |         ccc|
|==|==|============|
|1 |3 |           5|
|97|17|<0.464543.0>|
```

#### Using `pad_char` in third column
```
kz_log:print_table([[<<"a">>, <<"B">>, <<"ccc">>], [1, 3, 5], [$a, 17, self()]], #{header_divider => $=, row_spacing => [#{justification => left}, #{justification => left}, #{pad_char => $0}]}).
|a |B |000000000ccc|
|==|==|============|
|1 |3 |000000000005|
|97|17|<0.464543.0>|
```

One caveat: you may not use `$*` as the pad character (see discussion around "general format" [here](https://www.erlang.org/docs/23/man/io#fwrite-3)).

#### Practical example

Before:

```
> kazoo_amqp_maintenance:channel_summary().
+--------------------------------------------------+----------+----------+----------------------+-----------------+-----------------+-----------------+----------+----------+
| Broker                                           |   Age    | Assigned |      Application     |     Consumer    |     Channel     |   Connection    |   Type   | Watchers |
+==================================================+==========+==========+======================+=================+=================+=================+==========+==========+
| amqp://guest:guest@localhost:5672                | 33222    | 33219    | kazoo_nodes          | <0.349.0>       | <0.294.0>       | <0.278.0>       | float    | 0        |
+--------------------------------------------------+----------+----------+----------------------+-----------------+-----------------+-----------------+----------+----------+
| amqp://guest:guest@localhost:5672                | 33222    | 33218    | kazoo_caches         | <0.359.0>       | <0.298.0>       | <0.278.0>       | float    | 0        |
+--------------------------------------------------+----------+----------+----------------------+-----------------+-----------------+-----------------+----------+----------+
```

This was all hard-coded format strings. When PIDs exceed the column width, all `*********` get printed - hardly helpful.

Now, the dynamically created table:

```
> kazoo_amqp_maintenance:channel_summary().
|                           Broker|  Age|Assigned|  Application|  Consumer|   Channel|Connection| Type|Watchers|
|=================================|=====|========|=============|==========|==========|==========|=====|========|
|amqp://guest:guest@localhost:5672|33518|   33515|  kazoo_nodes| <0.349.0>| <0.294.0>| <0.278.0>|float|       0|
|amqp://guest:guest@localhost:5672|33518|   33514| kazoo_caches| <0.359.0>| <0.298.0>| <0.278.0>|float|       0|
```

Under the covers this code is run to generate the above:

```erlang
    kz_log:print_table([HeaderFields | Rows]
                      ,#{header_divider => $=}
                      ).
```

#### Short-cut

It is tedious to have to create a map with `justification => left` for each column you want left-justified. Cell spacing parameters can short cut to `left` to avoid some boilerplate:

```
> kz_log:print_table([[a, b], ["aaa", "bbb"]], #{row_spacing => ['left', 'left']}).
|a  |b  |
|aaa|bbb|
```
