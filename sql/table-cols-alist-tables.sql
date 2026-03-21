with
        _pk_fk_matrix as (
                select
                        c1.constraint_schema as fscm,
                        c1.table_name as ftbl,
                        kc1.column_name as fcol,
                        kc2.column_name as pcol,
                        c2.table_name as ptbl,
                        c2.constraint_schema as pscm
                from
                        information_schema.referential_constraints
                        join information_schema.table_constraints c1 on information_schema.referential_constraints.constraint_name = c1.constraint_name
                        join information_schema.table_constraints c2 on information_schema.referential_constraints.unique_constraint_name = c2.constraint_name
                        join information_schema.key_column_usage kc1 on kc1.constraint_name = c1.constraint_name
                        join information_schema.key_column_usage kc2 on kc2.constraint_name = c2.constraint_name
                where
                        c2.table_name = any ($1)
                        or (
                                c1.table_name = any ($1)
                                and c1.constraint_type = 'FOREIGN KEY'
                        )
        )
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
        and kc.table_name = col.table_name
        left join information_schema.table_constraints cstr on kc.constraint_name = cstr.constraint_name
where

        col.table_name = any( ( select ftbl from _pk_fk_matrix ) )
        or col.table_name = any ( ( select ptbl from _pk_fk_matrix ) )
group by
        col.table_schema,
        col.table_name
;
