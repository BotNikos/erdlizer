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
        c2.constraint_schema = any($1)
        and c1.constraint_schema = any($1)
        and c1.constraint_type = 'FOREIGN KEY'
;
