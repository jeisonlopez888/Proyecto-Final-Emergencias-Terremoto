# =====================================================================
# UNIVERSIDAD DEL QUINDÍO - PROGRAMACIÓN III (PROYECTO FINAL)
# Autor: Jeison López
# FASE 5: SISTEMA CENTRAL E INTERFAZ DE CONSOLA INTERACTIVA (CLI)
# =====================================================================

Code.require_file(Path.expand("estructuras.exs", __DIR__))
Code.require_file(Path.expand("servidor_emergencia.exs", __DIR__))
Code.require_file(Path.expand("persistencia.exs", __DIR__))
Code.require_file(Path.expand("supervisor.exs", __DIR__))
Code.require_file(Path.expand("jerarquia_zonas.exs", __DIR__))
Code.require_file(Path.expand("personas_mascotas.exs", __DIR__))

defmodule SistemaEmergencia do
  @moduledoc """
  Punto de entrada principal de la aplicación.
  Inicializa el árbol de supervisión OTP, carga el estado persistente de los archivos
  y despliega la consola interactiva CLI.
  """

  def iniciar do
    IO.puts("""
    =====================================================================
    SISTEMA DISTRIBUIDO DE ATENCIÓN DE EMERGENCIAS (TERREMOTO)
    Universidad del Quindío - Programación III
    Desarrollado por: Jeison López
    =====================================================================
    """)

    # 1. Iniciar Árbol de Supervisión OTP
    case Emergencia.Supervisor.start_link() do
      {:ok, _pid} ->
        IO.puts("[OTP] Árbol de Supervisión activado exitosamente (:one_for_one).")

      {:error, {:already_started, _pid}} ->
        IO.puts("[OTP] Árbol de Supervisión ya activo.")
    end

    # 2. Cargar estado inicial desde archivos planos (.txt)
    cargar_datos_disco()

    # 3. Desplegar Menú Principal
    menu_principal(%{usuario: nil, mascotas: []})
  end

  defp cargar_datos_disco do
    IO.puts("[Persistencia] Cargando datos guardados en archivos planos...")

    {:ok, recursos} = Emergencia.Persistencia.cargar_recursos()
    Enum.each(recursos, &Emergencia.ServidorRecursos.registrar_recurso/1)

    {:ok, albergues} = Emergencia.Persistencia.cargar_albergues()
    Enum.each(albergues, &Emergencia.ServidorRecursos.registrar_albergue/1)

    {:ok, necesidades} = Emergencia.Persistencia.cargar_necesidades()
    Enum.each(necesidades, &Emergencia.ServidorRecursos.registrar_necesidad/1)

    IO.puts(
      "[OK] Estado recuperado: #{Enum.count(recursos)} recurso(s), #{Enum.count(albergues)} albergue(s), #{Enum.count(necesidades)} necesidad(es).\n"
    )
  end

  # -------------------------------------------------------------------
  # MENÚ PRINCIPAL E INTERACTIVIDAD CLI
  # -------------------------------------------------------------------

  defp menu_principal(estado_app) do
    usuario_str =
      if estado_app.usuario,
        do: "#{estado_app.usuario.nombre} (#{estado_app.usuario.tipo})",
        else: "Invitado"

    IO.puts("""
    ---------------------------------------------------------------------
    MENÚ PRINCIPAL | Usuario actual: #{usuario_str}
    ---------------------------------------------------------------------
    1. Iniciar Sesión / Registrar Usuario
    2. Consultar Recursos (GenServer Concurrente)
    3. Asignar Recurso (Transacción Atómica Protegida)
    4. Consultar y Registrar en Albergues (Control de Cupos)
    5. Registrar Necesidad de Emergencia
    6. Registrar y Buscar Coincidencias de Mascotas (Matching)
    7. Guardar Estado en Archivos Planos (.txt)
    8. Salir
    """)

    opcion = IO.gets("Seleccione una opción (1-8): ") |> String.trim()

    case opcion do
      "1" ->
        login_menu(estado_app)

      "2" ->
        consultar_recursos_menu(estado_app)

      "3" ->
        asignar_recurso_menu(estado_app)

      "4" ->
        albergues_menu(estado_app)

      "5" ->
        necesidad_menu(estado_app)

      "6" ->
        mascotas_menu(estado_app)

      "7" ->
        guardar_menu(estado_app)

      "8" ->
        IO.puts("\n¡Gracias por utilizar el Sistema de Gestión de Emergencias!")

      _ ->
        IO.puts("\nOpción inválida. Intente de nuevo.")
        menu_principal(estado_app)
    end
  end

  defp login_menu(estado_app) do
    nombre = IO.gets("Ingrese su nombre: ") |> String.trim()

    tipo =
      IO.gets("Tipo (coordinador / voluntario / ciudadano): ")
      |> String.trim()
      |> String.downcase()

    case Usuario.nuevo(String.downcase(nombre), "1234", nombre, tipo) do
      {:ok, u} ->
        IO.puts("\n[OK] Sesión iniciada como: #{u.nombre} [#{u.tipo}]")
        menu_principal(%{estado_app | usuario: u})

      {:error, err} ->
        IO.puts("\n[ERROR] #{err}")
        menu_principal(estado_app)
    end
  end

  defp consultar_recursos_menu(estado_app) do
    recursos = Emergencia.ServidorRecursos.consultar_recursos()

    IO.puts("\n=== INVENTARIO DE RECURSOS EN TIEMPO REAL ===")

    if recursos == [] do
      IO.puts("No hay recursos registrados.")
    else
      Enum.each(recursos, fn r ->
        IO.puts(
          "• [#{r.codigo}] #{r.nombre} | Cantidad: #{r.cantidad} #{r.unidad} | Ubicación: #{r.ubicacion}"
        )
      end)
    end

    menu_principal(estado_app)
  end

  defp asignar_recurso_menu(estado_app) do
    codigo = IO.gets("Código del recurso (ej: R01): ") |> String.trim()
    cant_str = IO.gets("Cantidad a solicitar: ") |> String.trim()

    case Integer.parse(cant_str) do
      {cant, ""} when cant > 0 ->
        case Emergencia.ServidorRecursos.asignar_recurso(codigo, cant) do
          {:ok, r} ->
            IO.puts(
              "\n[ÉXITO] Transacción realizada. Stock restante de #{r.nombre}: #{r.cantidad} #{r.unidad}"
            )

          {:error, err} ->
            IO.puts("\n[RECHAZADO] #{err}")
        end

      _ ->
        IO.puts("\n[ERROR] Cantidad debe ser un número entero positivo.")
    end

    menu_principal(estado_app)
  end

  defp albergues_menu(estado_app) do
    albergues = Emergencia.ServidorRecursos.consultar_albergues()

    IO.puts("\n=== ESTADO DE ALBERGUES Y CAPACIDAD ===")

    Enum.each(albergues, fn a ->
      IO.puts(
        "• [#{a.codigo}] #{a.nombre} | Ocupación: #{a.ocupacion_actual}/#{a.capacidad_maxima}"
      )
    end)

    ingresar? =
      IO.gets("\n¿Desea ingresar personas a un albergue? (s/n): ")
      |> String.trim()
      |> String.downcase()

    if ingresar? == "s" do
      cod = IO.gets("Código del albergue: ") |> String.trim()
      cant_str = IO.gets("Cantidad de personas: ") |> String.trim()

      with {cant, ""} <- Integer.parse(cant_str),
           {:ok, a_actualizado} <- Emergencia.ServidorRecursos.ingresar_albergue(cod, cant) do
        IO.puts(
          "\n[ÉXITO] Ingreso registrado. Nueva ocupación en '#{a_actualizado.nombre}': #{a_actualizado.ocupacion_actual}/#{a_actualizado.capacidad_maxima}"
        )
      else
        {:error, err} -> IO.puts("\n[RECHAZADO] #{err}")
        _ -> IO.puts("\n[ERROR] Cantidad inválida.")
      end
    end

    menu_principal(estado_app)
  end

  defp necesidad_menu(estado_app) do
    id = "N00" <> to_string(:rand.uniform(99))
    tipo = IO.gets("Tipo de necesidad (agua, comida, medicinas, refugio): ") |> String.trim()
    cant_str = IO.gets("Cantidad: ") |> String.trim()
    zona = IO.gets("Código de zona (ej: Z01): ") |> String.trim()

    with {cant, ""} <- Integer.parse(cant_str),
         {:ok, n} <- Necesidad.nueva(id, tipo, cant, :alta, zona) do
      Emergencia.ServidorRecursos.registrar_necesidad(n)
      IO.puts("\n[ÉXITO] Necesidad registrada con ID '#{n.id}' en estado :pendiente")
    else
      {:error, err} -> IO.puts("\n[ERROR] #{err}")
      _ -> IO.puts("\n[ERROR] Datos de entrada incorrectos.")
    end

    menu_principal(estado_app)
  end

  defp mascotas_menu(estado_app) do
    IO.puts("\n=== GESTIÓN Y MATCHING DE MASCOTAS ===")

    op =
      IO.gets(
        "1. Registrar Mascota Perdida\n2. Registrar Mascota Encontrada\n3. Buscar Coincidencias\nOpción: "
      )
      |> String.trim()

    case op do
      "1" ->
        id = "M00" <> to_string(:rand.uniform(99))
        esp = IO.gets("Especie (Perro/Gato): ") |> String.trim()
        nom = IO.gets("Nombre: ") |> String.trim()
        col = IO.gets("Color: ") |> String.trim()
        tam = IO.gets("Tamaño (grande/mediano/pequeno): ") |> String.trim()
        zona = IO.gets("Zona: ") |> String.trim()
        cont = IO.gets("Contacto: ") |> String.trim()

        {:ok, m} =
          Mascota.nueva(id, :perdida, esp, nom, "Perdida tras terremoto", col, tam, zona, cont)

        nuevas_mascotas = [m | estado_app.mascotas]
        IO.puts("\n[OK] Mascota perdida registrada con ID '#{m.id}'.")
        menu_principal(%{estado_app | mascotas: nuevas_mascotas})

      "2" ->
        id = "M00" <> to_string(:rand.uniform(99))
        esp = IO.gets("Especie (Perro/Gato): ") |> String.trim()
        col = IO.gets("Color: ") |> String.trim()
        tam = IO.gets("Tamaño (grande/mediano/pequeno): ") |> String.trim()
        zona = IO.gets("Zona: ") |> String.trim()
        cont = IO.gets("Contacto: ") |> String.trim()

        {:ok, m} =
          Mascota.nueva(
            id,
            :encontrada,
            esp,
            "Sin nombre",
            "Encontrada sola",
            col,
            tam,
            zona,
            cont
          )

        nuevas_mascotas = [m | estado_app.mascotas]
        IO.puts("\n[OK] Mascota encontrada registrada con ID '#{m.id}'.")
        menu_principal(%{estado_app | mascotas: nuevas_mascotas})

      "3" ->
        perdidas = Enum.filter(estado_app.mascotas, &(&1.tipo_reporte == :perdida))

        if perdidas == [] do
          IO.puts("\nNo hay mascotas perdidas registradas para buscar coincidencias.")
        else
          m_ref = hd(perdidas)

          coincidencias =
            Emergencia.MatchingMascotas.encontrar_coincidencias(m_ref, estado_app.mascotas)

          IO.puts(
            "\n--- RESULTADOS DE MATCHING PARA '#{m_ref.nombre}' (#{m_ref.especie}, #{m_ref.color}) ---"
          )

          if coincidencias == [] do
            IO.puts("No se encontraron coincidencias por encima del umbral.")
          else
            Enum.each(coincidencias, fn {m, score} ->
              IO.puts(
                "• ID #{m.id} (#{m.especie}, #{m.color}) | Contacto: #{m.contacto} | Coincidencia: #{score}%"
              )
            end)
          end
        end

        menu_principal(estado_app)

      _ ->
        menu_principal(estado_app)
    end
  end

  defp guardar_menu(estado_app) do
    recursos = Emergencia.ServidorRecursos.consultar_recursos()
    albergues = Emergencia.ServidorRecursos.consultar_albergues()
    necesidades = Emergencia.ServidorRecursos.consultar_necesidades()

    Emergencia.Persistencia.guardar_recursos(recursos)
    Emergencia.Persistencia.guardar_albergues(albergues)
    Emergencia.Persistencia.guardar_necesidades(necesidades)

    IO.puts(
      "\n[PERSISTENCIA ÉXITO] Datos sincronizados en recursos.txt, albergues.txt y necesidades.txt."
    )

    menu_principal(estado_app)
  end
end

# Iniciar la aplicación
SistemaEmergencia.iniciar()
