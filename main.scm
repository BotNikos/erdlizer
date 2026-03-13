(import (chicken io)
	(chicken string)
	(chicken random)
	(chicken format)
	(chicken process)
	(chicken process-context)
	(chicken file)
	srfi-1
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
			  (fscm (list-ref row 0)) (ftbl (list-ref row 1)) (fcol (list-ref row 2))
			  (pcol (list-ref row 3)) (ptbl (list-ref row 4)) (pscm (list-ref row 5)))
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

(define (get-arg args)
  (case (string->symbol (car args))
    ((-h --help) (print "    erdlizer --help
    Usage: erdlizer [OPTION...] schema...

    -h, --help		Show this help message
    -t, --type=type	Set output file type, it can be 'svg' or
    			'png', 'svg' is used by default
    -c, --config=path	Set path to configuration file, default value is './config'") (exit 1))
    ((-t --type) (cons 'type (cadr args)))
    ((-c --conf) (cons 'conf (cadr args)))
    (else (car args))))

(define (parse-args acc args)
  (if (null? args)
      (let-values (((schemas args) (partition string? acc)))
	(cons (cons 'schemas schemas) args))
      (parse-args (cons (get-arg args) acc)
		  (if (member (car args) '("-h" "--help" "-t" "--type" "-c" "--conf"))
		      (cddr args)
		      (cdr args)))))

(let* ((args (parse-args '() (command-line-arguments)))
       (type (cdr (or (assoc 'type args) '(type . "svg"))))
       (conf (read (open-input-file "config")))
       (conn (connect (cdr (assoc 'database conf))
		      (cons `("sql_identifier" . ,identity)
			    (default-type-parsers))))
       (table-cols-sql (read-string #f (open-input-file "table-cols-alist.sql")))
       (pk-fk-matrix-sql (read-string #f (open-input-file "pk-fk-matrix.sql")))
       (pk-fk-matrix (get-list-from-query (query conn pk-fk-matrix-sql (list->vector (cdr (assoc 'schemas args))))))
       (table-cols (get-list-from-query (query conn table-cols-sql (list->vector (cdr (assoc 'schemas args)))))))
  
  (display (fill-file conf table-cols pk-fk-matrix) (open-output-file "/tmp/erd-gen.uml"))
  (process-wait (process-run "java" `("-jar" ,(cdr (assoc 'plantuml conf))
				      ,(conc "-t" type)
				      "/tmp/erd-gen.uml")))
  (move-file (conc "/tmp/erd-gen." type) (conc "./result." type) #t))
