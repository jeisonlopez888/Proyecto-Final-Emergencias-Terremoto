# =====================================================================
# UNIVERSIDAD DEL QUINDÍO - PROGRAMACIÓN III (PROYECTO FINAL)
# Autor: Jeison López
# =====================================================================

Code.require_file(Path.expand("estructuras.exs", __DIR__))
Code.require_file(Path.expand("servidor_emergencia.exs", __DIR__))
Code.require_file(Path.expand("persistencia.exs", __DIR__))
Code.require_file(Path.expand("supervisor.exs", __DIR__))
Code.require_file(Path.expand("jerarquia_zonas.exs", __DIR__))
Code.require_file(Path.expand("personas_mascotas.exs", __DIR__))

defmodule SistemaEmergencia do
  @moduledoc """
  Punto de entrada principal con menús por rol
  """

  @zonas_defecto [
    {"Z01", "Zona 1 Sur", :critico, 500},
    {"Z02", "Zona 2 Norte", :alto, 350},
    {"Z03", "Zona 3 Oriente", :medio, 200},
    {"Z04", "Zona 4 Occidente", :alto, 400},
    {"Z05", "Zona 5 Centro", :critico, 600}
  ]

  @albergues_defecto [
    {"A01", "Estadio Centenario", "Z01", 300},
    {"A02", "Coliseo del Café", "Z02", 250},
    {"A03", "Bodega de la Catedral", "Z05", 150},
    {"A04", "Auditorio Cruz Roja", "Z04", 100},
    {"A05", "CAI Parque de la Constitución", "Z03", 80}
  ]

  @recursos_defecto [
    {"R01", "Agua Potable 5L", "Hidratación", 100, "botellones", "Estadio Centenario"},
    {"R02", "Kits de Primeros Auxilios", "Salud", 50, "cajas", "Auditorio Cruz Roja"},
    {"R03", "Cobijas y Frazadas", "Abrigo", 200, "unidades", "Coliseo del Café"},
    {"R04", "Raciones de Comida no Perecedera", "Alimentación", 150, "paquetes",
     "Bodega de la Catedral"},
    {"R05", "Colchonetas Térmicas", "Refugio", 60, "unidades", "CAI Parque de la Constitución"}
  ]

  def iniciar do
    IO.puts("""
    =====================================================================
    SISTEMA DISTRIBUIDO DE ATENCIÓN DE EMERGENCIAS (TERREMOTO)
    Universidad del Quindío - Programación III
    Desarrollado por: Jeison López
    =====================================================================
    """)

    case Emergencia.Supervisor.start_link() do
      {:ok, _pid} -> IO.puts("[OTP] Árbol de Supervisión activado exitosamente (:one_for_one).")
      {:error, {:already_started, _pid}} -> IO.puts("[OTP] Árbol de Supervisión ya activo.")
    end

    cargar_datos_disco()
    menu_autenticacion(%{usuario: nil, mascotas: []})
  end

  defp cargar_datos_disco do
    IO.puts("[Persistencia] Inicializando y sincronizando catálogo de datos...")

    {:ok, z_carg} = Emergencia.Persistencia.cargar_zonas()

    z_fin =
      if z_carg == [] do
        Enum.map(@zonas_defecto, fn {c, n, nv, p} ->
          {:ok, z} = Zona.nueva(c, n, nv, p)
          z
        end)
      else
        z_carg
      end

    Enum.each(z_fin, &Emergencia.ServidorRecursos.registrar_zona/1)

    {:ok, u_carg} = Emergencia.Persistencia.cargar_usuarios()

    u_fin =
      if u_carg == [] do
        {:ok, admin} =
          Usuario.nuevo("jeison", "1234", "Jeison López", :coordinador, "Zona 5 Centro")

        [admin]
      else
        u_carg
      end

    Enum.each(u_fin, &Emergencia.ServidorRecursos.registrar_usuario/1)

    {:ok, a_carg} = Emergencia.Persistencia.cargar_albergues()

    a_fin =
      if a_carg == [] do
        Enum.map(@albergues_defecto, fn {c, n, z, cp} ->
          {:ok, a} = Albergue.nuevo(c, n, z, cp, "Sistema")
          a
        end)
      else
        a_carg
      end

    Enum.each(a_fin, fn a ->
      Emergencia.ServidorRecursos.registrar_albergue(a, a.registrado_por)
    end)

    {:ok, r_carg} = Emergencia.Persistencia.cargar_recursos()

    r_fin =
      if r_carg == [] do
        Enum.map(@recursos_defecto, fn {c, n, ct, cn, un, ub} ->
          {:ok, r} = Recurso.nuevo(c, n, ct, cn, un, ub, "Sistema")
          r
        end)
      else
        r_carg
      end

    Enum.each(r_fin, fn r ->
      Emergencia.ServidorRecursos.registrar_recurso(r, r.registrado_por)
    end)

    {:ok, nec} = Emergencia.Persistencia.cargar_necesidades()
    Enum.each(nec, &Emergencia.ServidorRecursos.registrar_necesidad/1)

    {:ok, pers} = Emergencia.Persistencia.cargar_personas()
    Enum.each(pers, &Emergencia.ServidorRecursos.registrar_persona/1)

    {:ok, msgs} = Emergencia.Persistencia.cargar_mensajes()
    Enum.each(msgs, &Emergencia.ServidorRecursos.registrar_mensaje/1)

    IO.puts(
      "[OK] Estado listo: #{length(z_fin)} zonas, #{length(a_fin)} albergues, #{length(r_fin)} recursos, #{length(u_fin)} usuarios, #{length(pers)} personas censadas.\n"
    )
  end

  # --- SELECCIONES GUIADAS ---
  defp seleccionar_zona do
    zonas = Emergencia.ServidorRecursos.consultar_zonas() |> Enum.sort_by(fn z -> z.codigo end)
    IO.puts("\n--- SELECCIONE LA ZONA DE LA CIUDAD ---")
    indexed = Enum.with_index(zonas, 1)

    Enum.each(indexed, fn {z, idx} ->
      IO.puts("  #{idx}. [#{z.codigo}] #{z.nombre} (Afectación: #{z.nivel_afectacion})")
    end)

    op_str = IO.gets("Seleccione (1-#{length(zonas)}): ") |> String.trim()

    case Integer.parse(op_str) do
      {num, ""} when num >= 1 and num <= length(zonas) ->
        {:ok, elem(Enum.at(indexed, num - 1), 0)}

      _ ->
        {:error, "Zona inválida"}
    end
  end

  defp seleccionar_albergue_menu do
    albergues =
      Emergencia.ServidorRecursos.consultar_albergues() |> Enum.sort_by(fn a -> a.codigo end)

    if albergues == [] do
      {:error, "No hay albergues o centros de acopio registrados."}
    else
      IO.puts("\n--- SELECCIONE EL ALBERGUE ---")
      indexed = Enum.with_index(albergues, 1)

      Enum.each(indexed, fn {a, idx} ->
        IO.puts(
          "  #{idx}. [#{a.codigo}] #{a.nombre} (Ocupación: #{a.ocupacion_actual}/#{a.capacidad_maxima})"
        )
      end)

      op_str = IO.gets("Seleccione (1-#{length(albergues)}): ") |> String.trim()

      case Integer.parse(op_str) do
        {num, ""} when num >= 1 and num <= length(albergues) ->
          {:ok, elem(Enum.at(indexed, num - 1), 0)}

        _ ->
          {:error, "Albergue inválido"}
      end
    end
  end

  defp seleccionar_recurso_menu do
    recursos =
      Emergencia.ServidorRecursos.consultar_recursos() |> Enum.sort_by(fn r -> r.codigo end)

    if recursos == [] do
      {:error, "No hay recursos registrados en el inventario."}
    else
      IO.puts("\n--- SELECCIONE EL RECURSO DISPONIBLE ---")
      indexed = Enum.with_index(recursos, 1)

      Enum.each(indexed, fn {r, idx} ->
        IO.puts(
          "  #{idx}. [#{r.codigo}] #{r.nombre} | Stock: #{r.cantidad} #{r.unidad} | Ubicación: #{r.ubicacion}"
        )
      end)

      op_str =
        IO.gets("Seleccione el número del recurso (1-#{length(recursos)}): ") |> String.trim()

      case Integer.parse(op_str) do
        {num, ""} when num >= 1 and num <= length(recursos) ->
          {:ok, elem(Enum.at(indexed, num - 1), 0)}

        _ ->
          {:error, "Selección de recurso inválida."}
      end
    end
  end

  defp seleccionar_estado_persona do
    IO.puts("\n--- SELECCIONE EL ESTADO DE LA PERSONA ---")

    IO.puts(
      "  1. sin_informacion\n  2. reportada\n  3. localizada\n  4. trasladada\n  5. en_albergue\n  6. reunificada"
    )

    case IO.gets("Seleccione (1-6): ") |> String.trim() do
      "1" -> :sin_informacion
      "2" -> :reportada
      "3" -> :localizada
      "4" -> :trasladada
      "5" -> :en_albergue
      _ -> :reunificada
    end
  end

  # --- AUTENTICACIÓN ---
  defp menu_autenticacion(estado_app) do
    IO.puts("""
    =====================================================================
    ACCESO RESTRINGIDO | AUTENTICACIÓN DE USUARIO REQUERIDA
    =====================================================================
    1. Iniciar Sesión (Login)
    2. Registrar Nuevo Usuario (Sign Up)
    3. Salir del Sistema
    """)

    case IO.gets("Seleccione opción (1-3): ") |> String.trim() do
      "1" -> iniciar_sesion(estado_app)
      "2" -> registrar_usuario_menu(estado_app)
      "3" -> IO.puts("\nSaliendo...")
      _ -> menu_autenticacion(estado_app)
    end
  end

  defp iniciar_sesion(estado_app) do
    IO.puts("\n--- INICIO DE SESIÓN ---")
    username = IO.gets("ingrese su nombre de usuario: ") |> String.trim() |> String.downcase()
    password = IO.gets("Contraseña: ") |> String.trim()

    case Emergencia.ServidorRecursos.autenticar_usuario(username, password) do
      {:ok, %{__struct__: Usuario} = u} ->
        IO.puts("\n[ACCESO CONCEDIDO] Bienvenido/a #{u.nombre} [Rol: #{u.tipo}]")
        despachar_menu_por_rol(%{estado_app | usuario: u})

      {:error, mot} ->
        IO.puts("\n[ACCESO DENEGADO] #{mot}")
        menu_autenticacion(estado_app)
    end
  end

  defp registrar_usuario_menu(estado_app) do
    IO.puts("\n--- REGISTRO DE USUARIO ---")
    usr = IO.gets("Username: ") |> String.trim() |> String.downcase()
    pwd = IO.gets("Contraseña: ") |> String.trim()
    nom = IO.gets("Nombre Completo: ") |> String.trim()
    IO.puts("Rol: 1. Ciudadano | 2. Voluntario | 3. Coordinador")

    tipo =
      case IO.gets("Seleccione (1-3): ") |> String.trim() do
        "1" -> "ciudadano"
        "2" -> "voluntario"
        _ -> "coordinador"
      end

    {:ok, z} = seleccionar_zona()

    case Usuario.nuevo(usr, pwd, nom, tipo, z.nombre) do
      {:ok, nuevo_u} ->
        Emergencia.ServidorRecursos.registrar_usuario(nuevo_u)
        Emergencia.Persistencia.guardar_usuarios(Emergencia.ServidorRecursos.consultar_usuarios())
        IO.puts("\n[ÉXITO] Usuario registrado. Inicie sesión.")
        menu_autenticacion(estado_app)

      {:error, err} ->
        IO.puts("\n[ERROR] #{err}")
        menu_autenticacion(estado_app)
    end
  end

  # --- ENRUTADOR POR ROL ---
  defp despachar_menu_por_rol(%{usuario: %{__struct__: Usuario, tipo: :ciudadano}} = estado_app),
    do: menu_ciudadano(estado_app)

  defp despachar_menu_por_rol(%{usuario: %{__struct__: Usuario, tipo: :voluntario}} = estado_app),
    do: menu_voluntario(estado_app)

  defp despachar_menu_por_rol(%{usuario: %{__struct__: Usuario, tipo: t}} = estado_app)
       when t in [:coordinador, :administrador], do: menu_coordinador(estado_app)

  # --- 1. MENÚ CIUDADANO ---
  defp menu_ciudadano(estado_app) do
    u = estado_app.usuario

    IO.puts("""
    ---------------------------------------------------------------------
    MENÚ CIUDADANO | Usuario: #{u.nombre}
    ---------------------------------------------------------------------
    1. Ver Zonas de la Ciudad
    2. Consultar Albergues
    3. Solicitar Necesidad de Emergencia
    4. Buscar Persona Afectada / Ver Mensajes (1.4.6)
    5. Dejar Mensaje Familiar a Persona (1.4.6)
    6. Mascotas Perdidas/Encontradas
    7. Cerrar Sesión
    8. Salir
    """)

    case IO.gets("Seleccione (1-8): ") |> String.trim() do
      "1" ->
        ver_zonas()
        menu_ciudadano(estado_app)

      "2" ->
        ver_albergues()
        menu_ciudadano(estado_app)

      "3" ->
        registrar_necesidad_menu(estado_app)
        menu_ciudadano(estado_app)

      "4" ->
        buscar_persona_menu()
        menu_ciudadano(estado_app)

      "5" ->
        dejar_mensaje_menu(estado_app)
        menu_ciudadano(estado_app)

      "6" ->
        estado_app = mascotas_menu(estado_app)
        menu_ciudadano(estado_app)

      "7" ->
        menu_autenticacion(%{estado_app | usuario: nil})

      "8" ->
        IO.puts("\n¡Hasta pronto!")

      _ ->
        menu_ciudadano(estado_app)
    end
  end

  # --- 2. MENÚ VOLUNTARIO ---
  defp menu_voluntario(estado_app) do
    u = estado_app.usuario

    IO.puts("""
    ---------------------------------------------------------------------
    MENÚ VOLUNTARIO | Usuario: #{u.nombre}
    ---------------------------------------------------------------------
    1. Ver Zonas de la Ciudad
    2. Consultar Recursos
    3. Ingresar Personas a Albergue
    4. Registrar Persona en Censo (1.4.6)
    5. Actualizar Estado de Persona Afectada (1.4.6)
    6. Registrar Necesidad
    7. Ver y Gestionar Mensajes Familiares (1.4.6)
    8. Mascotas
    9. Cerrar Sesión
    10. Salir
    """)

    case IO.gets("Seleccione (1-10): ") |> String.trim() do
      "1" ->
        ver_zonas()
        menu_voluntario(estado_app)

      "2" ->
        ver_recursos()
        menu_voluntario(estado_app)

      "3" ->
        ingresar_albergue_op(estado_app)
        menu_voluntario(estado_app)

      "4" ->
        registrar_persona_menu()
        menu_voluntario(estado_app)

      "5" ->
        actualizar_estado_persona_menu()
        menu_voluntario(estado_app)

      "6" ->
        registrar_necesidad_menu(estado_app)
        menu_voluntario(estado_app)

      "7" ->
        gestionar_mensajes_menu()
        menu_voluntario(estado_app)

      "8" ->
        estado_app = mascotas_menu(estado_app)
        menu_voluntario(estado_app)

      "9" ->
        menu_autenticacion(%{estado_app | usuario: nil})

      "10" ->
        IO.puts("\n¡Hasta pronto!")

      _ ->
        menu_voluntario(estado_app)
    end
  end

  # --- 3. MENÚ COORDINADOR ---
  defp menu_coordinador(estado_app) do
    u = estado_app.usuario

    IO.puts("""
    ---------------------------------------------------------------------
    MENÚ COORDINADOR | Usuario: #{u.nombre}
    ---------------------------------------------------------------------
    1. Ver Zonas de la Ciudad
    2. Consultar Inventario de Recursos
    3. Asignar Recurso a Emergencia
    4. Registrar Nuevo Recurso
    5. Ver y Crear Albergues
    6. Censo Completo de Personas Afectadas y Control de Estados (1.4.6)
    7. Central de Mensajería Familiar (1.4.6)
    8. Registrar Necesidad
    9. Mascotas
    10. Guardar Estado en Disco (.txt)
    11. Ver Bitácora de Transacciones / Auditoría
    12. Cerrar Sesión
    13. Salir
    """)

    case IO.gets("Seleccione (1-13): ") |> String.trim() do
      "1" ->
        ver_zonas()
        menu_coordinador(estado_app)

      "2" ->
        ver_recursos()
        menu_coordinador(estado_app)

      "3" ->
        asignar_recurso_op(estado_app)
        menu_coordinador(estado_app)

      "4" ->
        registrar_recurso_op(estado_app)
        menu_coordinador(estado_app)

      "5" ->
        albergues_coord_op(estado_app)
        menu_coordinador(estado_app)

      "6" ->
        censo_coordinador_menu()
        menu_coordinador(estado_app)

      "7" ->
        gestionar_mensajes_menu()
        menu_coordinador(estado_app)

      "8" ->
        registrar_necesidad_menu(estado_app)
        menu_coordinador(estado_app)

      "9" ->
        estado_app = mascotas_menu(estado_app)
        menu_coordinador(estado_app)

      "10" ->
        guardar_disco(estado_app)
        menu_coordinador(estado_app)

      "11" ->
        ver_bitacora()
        menu_coordinador(estado_app)

      "12" ->
        menu_autenticacion(%{estado_app | usuario: nil})

      "13" ->
        IO.puts("\n¡Hasta pronto!")

      _ ->
        menu_coordinador(estado_app)
    end
  end

  # --- FUNCIONES DE COMUNICACIÓN FAMILIAR Y CENSO (REQUERIMIENTO 1.4.6) ---

  defp registrar_persona_menu do
    IO.puts("\n--- REGISTRAR PERSONA AFECTADA (CENSO) ---")
    doc = IO.gets("Documento o dato de referencia: ") |> String.trim()
    nom = IO.gets("Nombre completo: ") |> String.trim()
    edad_str = IO.gets("Edad: ") |> String.trim()
    {:ok, z} = seleccionar_zona()
    est = seleccionar_estado_persona()

    with {edad, ""} <- Integer.parse(edad_str),
         {:ok, p} <- Persona.nueva(doc, nom, z.codigo, edad, est) do
      Emergencia.ServidorRecursos.registrar_persona(p)
      Emergencia.Persistencia.guardar_personas(Emergencia.ServidorRecursos.consultar_personas())

      IO.puts(
        "\n[ÉXITO CENSO] Persona '#{p.nombre}' (Doc: #{p.documento}) registrada en estado :#{p.estado}."
      )
    else
      {:error, err} -> IO.puts("\n[ERROR] #{err}")
      _ -> IO.puts("\n[ERROR] Edad inválida.")
    end
  end

  defp buscar_persona_menu do
    IO.puts("\n--- BÚSQUEDA MULTICRITERIO DE PERSONAS AFECTADAS ---")
    IO.puts("Criterio de búsqueda: 1. Documento | 2. Nombre | 3. Zona | 4. Estado")

    crit =
      case IO.gets("Seleccione (1-4): ") |> String.trim() do
        "1" -> :documento
        "2" -> :nombre
        "3" -> :zona
        _ -> :estado
      end

    val = IO.gets("Ingrese el valor a buscar: ") |> String.trim()
    coincidencias = Emergencia.ServidorRecursos.buscar_personas(crit, val)

    IO.puts("\n=== RESULTADOS DEL CENSO DE PERSONAS ===")

    if coincidencias == [] do
      IO.puts("No se encontraron registros que coincidan con '#{val}'.")
    else
      Enum.each(coincidencias, fn p ->
        IO.puts(
          "\n• [DOC: #{p.documento}] #{p.nombre} (#{p.edad} años) | Zona: #{p.zona_codigo} | Estado Actual: :#{p.estado}"
        )

        IO.puts("  Historial de Estados:")

        Enum.each(p.historial_estados, fn {st, ts} ->
          IO.puts("    -> Estado :#{st} | Fecha UTC: #{ts}")
        end)

        msgs = Emergencia.ServidorRecursos.consultar_mensajes_destinatario(p.documento)

        if msgs != [] do
          IO.puts("  Mensajes Familiares Recibidos (#{length(msgs)}):")

          Enum.each(msgs, fn m ->
            IO.puts(
              "    * [ID: #{m.id}] De: #{m.remitente} | Estado: :#{m.estado} | Fecha: #{m.fecha} | Contenido: \"#{m.contenido}\""
            )
          end)
        end
      end)
    end
  end

  defp actualizar_estado_persona_menu do
    IO.puts("\n--- ACTUALIZAR ESTADO DE PERSONA AFECTADA ---")
    doc = IO.gets("Documento de la persona: ") |> String.trim()
    nuevo_est = seleccionar_estado_persona()

    case Emergencia.ServidorRecursos.cambiar_estado_persona(doc, nuevo_est) do
      {:ok, p_act} ->
        Emergencia.Persistencia.guardar_personas(Emergencia.ServidorRecursos.consultar_personas())

        IO.puts(
          "\n[ESTADO ACTUALIZADO] '#{p_act.nombre}' cambió a estado :#{p_act.estado}. Historial preservado."
        )

      {:error, err} ->
        IO.puts("\n[ERROR] #{err}")
    end
  end

  defp dejar_mensaje_menu(estado_app) do
    u = estado_app.usuario
    IO.puts("\n--- REGISTRAR MENSAJE FAMILIAR ---")
    dest_doc = IO.gets("Documento de la persona/familiar destinatario: ") |> String.trim()
    cont = IO.gets("Mensaje para el familiar: ") |> String.trim()
    id = "MSG00" <> to_string(:rand.uniform(99))

    case MensajeFamiliar.nuevo(id, u.nombre, dest_doc, cont) do
      {:ok, m} ->
        Emergencia.ServidorRecursos.registrar_mensaje(m)
        Emergencia.Persistencia.guardar_mensajes(Emergencia.ServidorRecursos.consultar_mensajes())

        IO.puts(
          "\n[MENSAJE REGISTRADO] Mensaje enviado a destinatario Doc '#{dest_doc}' con estado :pendiente."
        )

      {:error, err} ->
        IO.puts("\n[ERROR] #{err}")
    end
  end

  defp gestionar_mensajes_menu do
    msgs = Emergencia.ServidorRecursos.consultar_mensajes()
    IO.puts("\n=== CENTRAL DE MENSAJERÍA FAMILIAR ===")

    if msgs == [] do
      IO.puts("No hay mensajes registrados.")
    else
      Enum.each(msgs, fn m ->
        IO.puts(
          "• [ID: #{m.id}] Remitente: #{m.remitente} -> Destinatario Doc: #{m.destinatario_doc} | Estado: :#{m.estado} | Fecha: #{m.fecha}"
        )

        IO.puts("  \"#{m.contenido}\"")
      end)

      IO.puts("\n¿Desea cambiar el estado de un mensaje? (s/n)")

      if String.downcase(IO.gets("> ") |> String.trim()) == "s" do
        id = IO.gets("ID del mensaje (ej: MSG0012): ") |> String.trim() |> String.upcase()
        IO.puts("Seleccione nuevo estado: 1. entregado | 2. pendiente")
        n_est = if String.trim(IO.gets("> ")) == "1", do: :entregado, else: :pendiente

        case Emergencia.ServidorRecursos.cambiar_estado_mensaje(id, n_est) do
          {:ok, m_act} ->
            Emergencia.Persistencia.guardar_mensajes(
              Emergencia.ServidorRecursos.consultar_mensajes()
            )

            IO.puts("\n[ÉXITO] Mensaje #{m_act.id} marcado como :#{m_act.estado}.")

          {:error, err} ->
            IO.puts("\n[ERROR] #{err}")
        end
      end
    end
  end

  defp censo_coordinador_menu do
    IO.puts("\n=== GESTIÓN GLOBAL DEL CENSO DE PERSONAS (1.4.6) ===")
    IO.puts("  1. Buscar Persona / Ver Historial y Mensajes")
    IO.puts("  2. Registrar Nueva Persona Afectada")
    IO.puts("  3. Cambiar Estado de Persona Afectada")

    case IO.gets("Seleccione (1-3): ") |> String.trim() do
      "1" -> buscar_persona_menu()
      "2" -> registrar_persona_menu()
      "3" -> actualizar_estado_persona_menu()
      _ -> :ok
    end
  end

  # --- OTRAS OPERACIONES DE CONSULTA Y GESTIÓN ---
  defp ver_zonas do
    zonas = Emergencia.ServidorRecursos.consultar_zonas() |> Enum.sort_by(fn z -> z.codigo end)
    IO.puts("\n=== ZONAS DE LA CIUDAD ===")

    Enum.each(zonas, fn z ->
      IO.puts(
        "• [#{z.codigo}] #{z.nombre} | Nivel: :#{z.nivel_afectacion} | Afectados: #{z.personas_afectadas}"
      )
    end)
  end

  defp ver_recursos do
    recursos =
      Emergencia.ServidorRecursos.consultar_recursos() |> Enum.sort_by(fn r -> r.codigo end)

    IO.puts("\n=== INVENTARIO DE RECURSOS ===")

    Enum.each(recursos, fn r ->
      IO.puts(
        "• [#{r.codigo}] #{r.nombre} | Stock: #{r.cantidad} #{r.unidad} | Ubicación: #{r.ubicacion}"
      )
    end)
  end

  defp ver_albergues do
    albergues =
      Emergencia.ServidorRecursos.consultar_albergues() |> Enum.sort_by(fn a -> a.codigo end)

    IO.puts("\n=== ALBERGUES Y CUPOS ===")

    Enum.each(albergues, fn a ->
      IO.puts(
        "• [#{a.codigo}] #{a.nombre} | Libre: #{a.capacidad_maxima - a.ocupacion_actual}/#{a.capacidad_maxima}"
      )
    end)
  end

  defp ingresar_albergue_op(estado_app) do
    u = estado_app.usuario

    case seleccionar_albergue_menu() do
      {:ok, a} ->
        cant_str = IO.gets("Cantidad de personas a ingresar: ") |> String.trim()

        with {cant, ""} <- Integer.parse(cant_str),
             {:ok, a_act} <-
               Emergencia.ServidorRecursos.ingresar_albergue(a.codigo, cant, u.nombre) do
          Emergencia.Persistencia.guardar_albergues(
            Emergencia.ServidorRecursos.consultar_albergues()
          )

          IO.puts(
            "\n[ÉXITO] Ingreso registrado. Nueva ocupación: #{a_act.ocupacion_actual}/#{a_act.capacidad_maxima}"
          )
        else
          {:error, err} -> IO.puts("\n[ERROR] #{err}")
          _ -> IO.puts("\n[ERROR] Cantidad inválida.")
        end

      {:error, err} ->
        IO.puts("\n[ERROR] #{err}")
    end
  end

  defp asignar_recurso_op(estado_app) do
    u = estado_app.usuario

    case seleccionar_recurso_menu() do
      {:ok, recurso_elegido} ->
        IO.puts(
          "\nHas seleccionado: [#{recurso_elegido.codigo}] #{recurso_elegido.nombre} (Stock disponible: #{recurso_elegido.cantidad} #{recurso_elegido.unidad})"
        )

        cant_str = IO.gets("Ingrese la cantidad a solicitar: ") |> String.trim()

        case Integer.parse(cant_str) do
          {cant, ""} when cant > 0 ->
            case Emergencia.ServidorRecursos.asignar_recurso(
                   recurso_elegido.codigo,
                   cant,
                   u.nombre
                 ) do
              {:ok, r} ->
                Emergencia.Persistencia.guardar_recursos(
                  Emergencia.ServidorRecursos.consultar_recursos()
                )

                IO.puts(
                  "\n[ÉXITO AUDITADO] Solicitud procesada por #{u.nombre}. Stock restante de '#{r.nombre}': #{r.cantidad} #{r.unidad}"
                )

              {:error, err} ->
                IO.puts("\n[RECHAZADO AUDITADO] #{err}")
            end

          _ ->
            IO.puts("\n[ERROR] Cantidad debe ser un número entero positivo.")
        end

      {:error, err} ->
        IO.puts("\n[ERROR] #{err}")
    end
  end

  defp registrar_recurso_op(estado_app) do
    u = estado_app.usuario
    cod = "R0" <> to_string(length(Emergencia.ServidorRecursos.consultar_recursos()) + 1)
    nom = IO.gets("Nombre del recurso: ") |> String.trim()
    cant_str = IO.gets("Cantidad: ") |> String.trim()
    uni = IO.gets("Unidad: ") |> String.trim()

    case seleccionar_albergue_menu() do
      {:ok, a} ->
        with {cant, ""} <- Integer.parse(cant_str),
             {:ok, r} <- Recurso.nuevo(cod, nom, "General", cant, uni, a.nombre, u.nombre) do
          Emergencia.ServidorRecursos.registrar_recurso(r, u.nombre)

          Emergencia.Persistencia.guardar_recursos(
            Emergencia.ServidorRecursos.consultar_recursos()
          )

          IO.puts("\n[ÉXITO] Recurso registrado.")
        else
          {:error, err} -> IO.puts("\n[ERROR] #{err}")
          _ -> IO.puts("\n[ERROR] Cantidad inválida.")
        end

      {:error, err} ->
        IO.puts("\n[ERROR] #{err}")
    end
  end

  defp albergues_coord_op(estado_app) do
    u = estado_app.usuario
    albergues = Emergencia.ServidorRecursos.consultar_albergues()
    IO.puts("1. Ingresar personas | 2. Crear nuevo albergue")

    case IO.gets("Seleccione (1-2): ") |> String.trim() do
      "1" ->
        ingresar_albergue_op(estado_app)

      "2" ->
        cod = "A0" <> to_string(length(albergues) + 1)
        nom = IO.gets("Nombre albergue: ") |> String.trim()
        {:ok, z} = seleccionar_zona()
        cap_str = IO.gets("Capacidad máxima: ") |> String.trim()

        with {cap, ""} <- Integer.parse(cap_str),
             {:ok, a} <- Albergue.nuevo(cod, nom, z.codigo, cap, u.nombre) do
          Emergencia.ServidorRecursos.registrar_albergue(a, u.nombre)

          Emergencia.Persistencia.guardar_albergues(
            Emergencia.ServidorRecursos.consultar_albergues()
          )

          IO.puts("\n[ÉXITO] Albergue creado.")
        else
          {:error, err} -> IO.puts("\n[ERROR] #{err}")
          _ -> IO.puts("\n[ERROR] Capacidad inválida.")
        end

      _ ->
        :ok
    end
  end

  defp registrar_necesidad_menu(estado_app) do
    u = estado_app.usuario
    id = "N00" <> to_string(:rand.uniform(99))
    tipo = IO.gets("Tipo de necesidad (agua/comida/medicinas/refugio): ") |> String.trim()
    cant_str = IO.gets("Cantidad: ") |> String.trim()
    {:ok, z} = seleccionar_zona()
    desc = IO.gets("Detalle: ") |> String.trim()

    with {cant, ""} <- Integer.parse(cant_str),
         {:ok, n} <- Necesidad.nueva(id, tipo, cant, :alta, z.codigo, u.nombre, desc, u.nombre) do
      Emergencia.ServidorRecursos.registrar_necesidad(n)

      Emergencia.Persistencia.guardar_necesidades(
        Emergencia.ServidorRecursos.consultar_necesidades()
      )

      IO.puts("\n[ÉXITO] Necesidad registrada.")
    else
      {:error, err} -> IO.puts("\n[ERROR] #{err}")
      _ -> IO.puts("\n[ERROR] Datos inválidos.")
    end
  end

  defp mascotas_menu(estado_app) do
    u = estado_app.usuario
    IO.puts("\n=== MASCOTAS ===")
    IO.puts("1. Registrar Perdida | 2. Registrar Encontrada | 3. Buscar Coincidencias")

    case IO.gets("Seleccione (1-3): ") |> String.trim() do
      "1" ->
        id = "M00" <> to_string(:rand.uniform(99))
        esp = IO.gets("Especie: ") |> String.trim()
        nom = IO.gets("Nombre: ") |> String.trim()
        col = IO.gets("Color: ") |> String.trim()
        tam = IO.gets("Tamaño (grande/mediano/pequeno): ") |> String.trim()
        {:ok, z} = seleccionar_zona()
        cont = IO.gets("Contacto: ") |> String.trim()

        {:ok, m} =
          Mascota.nueva(id, :perdida, esp, nom, "Perdida", col, tam, z.codigo, cont, u.nombre)

        IO.puts("\n[OK] Mascota registrada.")
        %{estado_app | mascotas: [m | estado_app.mascotas]}

      "2" ->
        id = "M00" <> to_string(:rand.uniform(99))
        esp = IO.gets("Especie: ") |> String.trim()
        col = IO.gets("Color: ") |> String.trim()
        tam = IO.gets("Tamaño: ") |> String.trim()
        {:ok, z} = seleccionar_zona()
        cont = IO.gets("Contacto: ") |> String.trim()

        {:ok, m} =
          Mascota.nueva(
            id,
            :encontrada,
            esp,
            "Sin nombre",
            "Encontrada",
            col,
            tam,
            z.codigo,
            cont,
            u.nombre
          )

        IO.puts("\n[OK] Mascota encontrada registrada.")
        %{estado_app | mascotas: [m | estado_app.mascotas]}

      "3" ->
        perdidas = Enum.filter(estado_app.mascotas, &(&1.tipo_reporte == :perdida))

        if perdidas != [] do
          m_ref = hd(perdidas)
          coinc = Emergencia.MatchingMascotas.encontrar_coincidencias(m_ref, estado_app.mascotas)

          Enum.each(coinc, fn {m, s} ->
            IO.puts("• ID #{m.id} (#{m.especie}) | Contacto: #{m.contacto} | Score: #{s}%")
          end)
        end

        estado_app

      _ ->
        estado_app
    end
  end

  defp guardar_disco(estado_app) do
    u = estado_app.usuario
    Emergencia.Persistencia.guardar_zonas(Emergencia.ServidorRecursos.consultar_zonas())
    Emergencia.Persistencia.guardar_usuarios(Emergencia.ServidorRecursos.consultar_usuarios())
    Emergencia.Persistencia.guardar_recursos(Emergencia.ServidorRecursos.consultar_recursos())
    Emergencia.Persistencia.guardar_albergues(Emergencia.ServidorRecursos.consultar_albergues())

    Emergencia.Persistencia.guardar_necesidades(
      Emergencia.ServidorRecursos.consultar_necesidades()
    )

    Emergencia.Persistencia.guardar_personas(Emergencia.ServidorRecursos.consultar_personas())
    Emergencia.Persistencia.guardar_mensajes(Emergencia.ServidorRecursos.consultar_mensajes())

    Emergencia.Persistencia.registrar_auditoria(
      u.nombre,
      "GUARDAR_ESTADO",
      "Guardado manual en disco"
    )

    IO.puts("\n[PERSISTENCIA ÉXITO] Todo sincronizado en disco.")
  end

  defp ver_bitacora do
    if File.exists?("bitacora_transacciones.txt") do
      File.stream!("bitacora_transacciones.txt") |> Enum.each(&IO.puts/1)
    end
  end
end

# Iniciar aplicación
SistemaEmergencia.iniciar()
