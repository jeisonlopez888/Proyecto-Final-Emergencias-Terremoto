Code.require_file(Path.expand("estructuras.exs", __DIR__))
Code.require_file(Path.expand("servidor_emergencia.exs", __DIR__))
Code.require_file(Path.expand("persistencia.exs", __DIR__))
Code.require_file(Path.expand("supervisor.exs", __DIR__))

# 1. Iniciar el Árbol de Supervisión OTP
{:ok, _sup_pid} = Emergencia.Supervisor.start_link()

# 2. Registrar datos en el servidor supervisado
{:ok, r1} = Recurso.nuevo("R01", "Kits Medicos", "Salud", 150, "cajas", "Hospital Movil")
{:ok, a1} = Albergue.nuevo("A01", "Albergue Estadio", "Z01", 200)

Emergencia.ServidorRecursos.registrar_recurso(r1)
Emergencia.ServidorRecursos.registrar_albergue(a1)

# 3. Guardar en archivos planos (.txt) usando Persistencia (Stream perezoso)
recursos = Emergencia.ServidorRecursos.consultar_recursos()
albergues = Emergencia.ServidorRecursos.consultar_albergues()

Emergencia.Persistencia.guardar_recursos(recursos)
Emergencia.Persistencia.guardar_albergues(albergues)

IO.puts("--- DATOS GUARDADOS EN DISCO ---")
IO.puts("Recursos guardados: #{Enum.count(recursos)}")
IO.puts("Albergues guardados: #{Enum.count(albergues)}")

# 4. Probar Tolerancia a Fallos (Simulación de CRASH del Servidor)
pid_inicial = Process.whereis(Emergencia.ServidorRecursos)
IO.puts("\n--- DEMOSTRACION DE TOLERANCIA A FALLOS (SUPERVISOR OTP) ---")
IO.puts("PID del Servidor antes del crash: #{inspect(pid_inicial)}")

# Forzamos la muerte del proceso (Simulación de error imprevisto)
Process.exit(pid_inicial, :kill)
:timer.sleep(100)

pid_nuevo = Process.whereis(Emergencia.ServidorRecursos)
IO.puts("PID del Servidor despues del crash: #{inspect(pid_nuevo)}")
IO.puts("¿Se reinicio automaticamente?: #{pid_inicial != pid_nuevo and not is_nil(pid_nuevo)}")

# 5. Cargar datos desde disco para restaurar el estado después del reinicio
{:ok, recs_cargados} = Emergencia.Persistencia.cargar_recursos()
Enum.each(recs_cargados, &Emergencia.ServidorRecursos.registrar_recurso/1)

recs_post_crash = Emergencia.ServidorRecursos.consultar_recursos()
IO.puts("Recursos recuperados desde archivo tras el crash: #{inspect(recs_post_crash)}")
