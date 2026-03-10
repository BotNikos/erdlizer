(import (chicken io)
	(chicken string)
	(chicken random)
	(chicken format)
	(chicken process)
	(chicken file)
	srfi-13
	postgresql)

(define (get-list-from-query res)
 (row-fold (lambda (row acc) (cons row acc)) '() res))

(define (get-rand-color conf)
  (let* ((color-ll (cdr (assoc 'color-ll conf)))
	 (color-ul (cdr (assoc 'color-ul conf)))
	 (colors (map (lambda (x) (string-pad (number->string x 16) 2 #\0))
		      (map (lambda (x) (+ color-ll (remainder x (- color-ul color-ll))))
			   (map pseudo-random-integer
				(list color-ul color-ul color-ul))))))
    (conc "#" (string-join colors ""))))

(define (fill-tables tables acc)
  (if (null? tables)
      acc
      (fill-tables (cdr tables)
		   (let* ((row (car tables))
			  (schema (car row))
			  (table-name (cadr row))
			  (cols (caddr row)))
		     (conc acc "entity " schema "." table-name " {\n"
			   (let loop ((len (vector-length cols))
				      (i 0)
				      (acc ""))
			     (if (< i len)
				 (loop len (+ i 1) (conc acc "\t" (vector-ref cols i) "\n"))
				 acc))
			   "}\n\n")))))

(define (fill-matrix conf matrix acc)
  (if (null? matrix)
      acc
      (fill-matrix conf (cdr matrix)
		   (let* ((row (car matrix))
			  (fscm (list-ref row 0))
			  (ftbl (list-ref row 1))
			  (fcol (list-ref row 2))
			  (pcol (list-ref row 3))
			  (ptbl (list-ref row 4))
			  (pscm (list-ref row 5)))
		     (conc acc
			   fscm "." ftbl "::" fcol
			   " -up-> "
			   pscm "." ptbl "::" pcol
			   " " (get-rand-color conf) ";line.bold :"
			   fcol
			   "\n")))))

(define (fill-file conf tables matrix)
  (conc "@startuml\n"
	"skinparam package {\n"
	"\tBackgroundColor #" (cdr (assoc 'background conf)) "\n"
	"}\n"
	"!pragma layout elk\n"
	(fill-tables tables "")
	(fill-matrix conf matrix "")
	"@enduml\n"))

(let* ((conf (read (open-input-file "config")))
       (conn (connect (cdr (assoc 'database conf))
		      (cons `("sql_identifier" . ,identity)
			    (default-type-parsers))))
       (table-cols-sql (read-string #f (open-input-file "table-cols-alist.sql")))
       (pk-fk-matrix-sql (read-string #f (open-input-file "pk-fk-matrix.sql")))
       
       (pk-fk-matrix (get-list-from-query (query conn pk-fk-matrix-sql)))
       (table-cols  (get-list-from-query (query conn table-cols-sql))))
 
  (display (fill-file conf table-cols pk-fk-matrix) (open-output-file "/tmp/erd-gen.uml"))
  (process-wait (process-run "java" '("-jar" "/home/nikita/plantuml.jar" "-tsvg" "/tmp/erd-gen.uml")))
  (move-file "/tmp/erd-gen.svg" "./result.svg" #t))

