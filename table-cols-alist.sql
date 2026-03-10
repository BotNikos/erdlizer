select
        table_schema,
        table_name,
        array_agg(column_name)
from
        information_schema.columns
where
        table_schema ~ '^_.*'
group by
        table_schema,
        table_name
;
