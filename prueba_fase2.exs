Code.require_file(Path.expand("estructuras.exs", __DIR__))
Code.require_file(Path.expand("servidor_emergencia.exs", __DIR__))

{:ok, _pid} = Emergencia.ServidorRecursos.start_link()

# 1. Registro de recurso inicial (50 botellones)
{:ok, r1} =
  Recurso.nuevo("R01", "Agua Potable 5L", "Hidratación", 50, "botellones", "Acopio Central")

Emergencia.ServidorRecursos.registrar_recurso(r1)

# 2. Dos procesos simultáneos solicitan 30 botellones cada uno (Total requerido: 60)
t1 = Task.async(fn -> Emergencia.ServidorRecursos.asignar_recurso("R01", 30) end)
t2 = Task.async(fn -> Emergencia.ServidorRecursos.asignar_recurso("R01", 30) end)

IO.puts("Resultado Proceso 1: #{inspect(Task.await(t1))}")
IO.puts("Resultado Proceso 2: #{inspect(Task.await(t2))}")
