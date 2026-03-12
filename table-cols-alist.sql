select
        table_schema,
        table_name,
        array_agg(column_name)
from
        information_schema.columns
where
        table_schema = any($1)
group by
        table_schema,
        table_name
;
