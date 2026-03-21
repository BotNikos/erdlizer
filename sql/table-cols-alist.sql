select
        col.table_schema,
        col.table_name,
        json_agg(
                json_build_object(
                        'name',
                        col.column_name,
                        'type',
                        cstr.constraint_type
                )
                order by
                        case
                                when cstr.constraint_type = 'PRIMARY KEY' then 1
                                when cstr.constraint_type = 'FOREIGN KEY' then 2
                                else 3
                        end asc
        )
from
        information_schema.columns col
        left join information_schema.key_column_usage kc on kc.column_name = col.column_name
        and kc.table_schema = col.table_schema
        and kc.table_name = col.table_namecolumns
        left join information_schema.table_constraints cstr on kc.constraint_name = cstr.constraint_name
where
        col.table_schema = any ($1)
group by
        col.table_schema,
        col.table_name
;
