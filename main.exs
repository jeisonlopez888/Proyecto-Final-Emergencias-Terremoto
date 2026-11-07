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
  Punto de entrada principal de la aplicación.
  - Interfaz CLI 100% intuitiva con menús numéricos (1, 2, 3...) para minimizar la escritura de texto.
  - Zonas, Albergues/Centros de Acopio y Recursos predefinidos.
  - Autenticación obligatoria y bitácora de auditoría.
  """

  # --- ZONAS PREDEFINIDAS DE LA CIUDAD ---
  @zonas_defecto [
    {"Z01", "Zona 1 Sur", :critico, 500},
    {"Z02", "Zona 2 Norte", :alto, 350},
    {"Z03", "Zona 3 Oriente", :medio, 200},
    {"Z04", "Zona 4 Occidente", :alto, 400},
    {"Z05", "Zona 5 Centro", :critico, 600}
  ]

  # --- ALBERGUES Y CENTROS DE ACOPIO PREDEFINIDOS ---
  @albergues_defecto [
    {"A01", "Estadio Centenario", "Z01", 300},
    {"A02", "Coliseo del Café", "Z02", 250},
    {"A03", "Bodega de la Catedral", "Z05", 150},
    {"A04", "Auditorio Cruz Roja", "Z04", 100},
    {"A05", "CAI Parque de la Constitución", "Z03", 80}
  ]

  # --- RECURSOS PREDEFINIDOS DE INICIALIZACIÓN ---
  @recursos_defecto [
    {"R01", "Agua Potable 5L", "Hidratación", 100, "botellones", "Estadio Centenario"},
    {"R02", "Kits de Primeros Auxilios", "Salud", 50, "cajas", "Auditorio Cruz Roja"},
    {"R03", "Cobijas y Frazadas", "Abrigo", 200, "unidades", "Coliseo del Café"},
    {"R04", "Raciones de Comida no Perecedera", "Alimentación", 150, "paquetes", "Bodega de la Catedral"},
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

    # 1. Iniciar Árbol de Supervisión OTP
    case Emergencia.Supervisor.start_link() do
      {:ok, _pid} ->
        IO.puts("[OTP] Árbol de Supervisión activado exitosamente (:one_for_one).")

      {:error, {:already_started, _pid}} ->
        IO.puts("[OTP] Árbol de Supervisión ya activo.")
    end

    # 2. Cargar estado e inicializar datos predefinidos
    cargar_datos_disco()

    # 3. Mostrar Puerta de Entrada (Acceso Obligatorio)
    menu_autenticacion(%{usuario: nil, mascotas: []})
  end

  defp cargar_datos_disco do
    IO.puts("[Persistencia] Inicializando y sincronizando catálogo de datos...")

    # Zonas
    {:ok, zonas_cargadas} = Emergencia.Persistencia.cargar_zonas()
    zonas_finales =
      if zonas_cargadas == [] do
        Enum.map(@zonas_defecto, fn {cod, nom, niv, cant} ->
          {:ok, z} = Zona.nueva(cod, nom, niv, cant)
          z
        end)
      else
        zonas_cargadas
      end
    Enum.each(zonas_finales, &Emergencia.ServidorRecursos.registrar_zona/1)
    Emergencia.Persistencia.guardar_zonas(Emergencia.ServidorRecursos.consultar_zonas())

    # Usuarios
    {:ok, usuarios_cargados} = Emergencia.Persistencia.cargar_usuarios()
    usuarios_finales =
      if usuarios_cargados == [] do
        {:ok, admin} = Usuario.nuevo("jeison", "1234", "Jeison López", :coordinador, "Zona 5 Centro")
        [admin]
      else
        usuarios_cargados
      end
    Enum.each(usuarios_finales, &Emergencia.ServidorRecursos.registrar_usuario/1)
    Emergencia.Persistencia.guardar_usuarios(Emergencia.ServidorRecursos.consultar_usuarios())

    # Albergues / Centros de acopio
    {:ok, albergues_cargados} = Emergencia.Persistencia.cargar_albergues()
    albergues_finales =
      if albergues_cargados == [] do
        Enum.map(@albergues_defecto, fn {cod, nom, zona, cap} ->
          {:ok, a} = Albergue.nuevo(cod, nom, zona, cap, "Sistema")
          a
        end)
      else
        albergues_cargados
      end
    Enum.each(albergues_finales, fn a -> Emergencia.ServidorRecursos.registrar_albergue(a, a.registrado_por) end)
    Emergencia.Persistencia.guardar_albergues(Emergencia.ServidorRecursos.consultar_albergues())

    # Recursos
    {:ok, recursos_cargados} = Emergencia.Persistencia.cargar_recursos()
    recursos_finales =
      if recursos_cargados == [] do
        Enum.map(@recursos_defecto, fn {cod, nom, cat, cant, uni, ubi} ->
          {:ok, r} = Recurso.nuevo(cod, nom, cat, cant, uni, ubi, "Sistema")
          r
        end)
      else
        recursos_cargados
      end
    Enum.each(recursos_finales, fn r -> Emergencia.ServidorRecursos.registrar_recurso(r, r.registrado_por) end)
    Emergencia.Persistencia.guardar_recursos(Emergencia.ServidorRecursos.consultar_recursos())

    # Necesidades
    {:ok, necesidades_cargadas} = Emergencia.Persistencia.cargar_necesidades()
    Enum.each(necesidades_cargadas, &Emergencia.ServidorRecursos.registrar_necesidad/1)

    num_z = Enum.count(Emergencia.ServidorRecursos.consultar_zonas())
    num_u = Enum.count(Emergencia.ServidorRecursos.consultar_usuarios())
    num_a = Enum.count(Emergencia.ServidorRecursos.consultar_albergues())
    num_r = Enum.count(Emergencia.ServidorRecursos.consultar_recursos())
    num_n = Enum.count(necesidades_cargadas)

    IO.puts("[OK] Datos listos: #{num_z} zonas, #{num_a} albergues/acopios, #{num_r} recursos, #{num_u} usuarios, #{num_n} necesidades.\n")
  end

  # -------------------------------------------------------------------
  # AYUDANTES INTUITIVOS DE SELECCIÓN POR NÚMEROS (1, 2, 3...)
  # -------------------------------------------------------------------

  defp seleccionar_zona do
    zonas = Emergencia.ServidorRecursos.consultar_zonas() |> Enum.sort_by(& &1.codigo)
    IO.puts("\n--- SELECCIONE LA ZONA DE LA CIUDAD ---")
    indexed = Enum.with_index(zonas, 1)
    Enum.each(indexed, fn {z, idx} ->
      IO.puts("  #{idx}. [#{z.codigo}] #{z.nombre} (Afectación: #{z.nivel_afectacion})")
    end)

    op_str = IO.gets("Seleccione el número de la zona (1-#{length(zonas)}): ") |> String.trim()
    case Integer.parse(op_str) do
      {num, ""} when num >= 1 and num <= length(zonas) ->
        {zona_elegida, _} = Enum.at(indexed, num - 1)
        {:ok, zona_elegida}

      _ ->
        {:error, "Selección de zona inválida."}
    end
  end

  defp seleccionar_albergue_menu do
    albergues = Emergencia.ServidorRecursos.consultar_albergues() |> Enum.sort_by(& &1.codigo)
    if albergues == [] do
      {:error, "No hay albergues o centros de acopio registrados."}
    else
      IO.puts("\n--- SELECCIONE EL ALBERGUE O CENTRO DE ACOPIO ---")
      indexed = Enum.with_index(albergues, 1)
      Enum.each(indexed, fn {a, idx} ->
        IO.puts("  #{idx}. [#{a.codigo}] #{a.nombre} (Zona: #{a.zona_codigo}) | Ocupación: #{a.ocupacion_actual}/#{a.capacidad_maxima}")
      end)

      op_str = IO.gets("Seleccione el número del albergue/acopio (1-#{length(albergues)}): ") |> String.trim()
      case Integer.parse(op_str) do
        {num, ""} when num >= 1 and num <= length(albergues) ->
          {albergue_elegido, _} = Enum.at(indexed, num - 1)
          {:ok, albergue_elegido}

        _ ->
          {:error, "Selección de albergue inválida."}
      end
    end
  end

  defp seleccionar_recurso_menu do
    recursos = Emergencia.ServidorRecursos.consultar_recursos() |> Enum.sort_by(& &1.codigo)
    if recursos == [] do
      {:error, "No hay recursos registrados en el inventario."}
    else
      IO.puts("\n--- SELECCIONE EL RECURSO DISPONIBLE ---")
      indexed = Enum.with_index(recursos, 1)
      Enum.each(indexed, fn {r, idx} ->
        IO.puts("  #{idx}. [#{r.codigo}] #{r.nombre} | Stock: #{r.cantidad} #{r.unidad} | Ubicación: #{r.ubicacion}")
      end)

      op_str = IO.gets("Seleccione el número del recurso (1-#{length(recursos)}): ") |> String.trim()
      case Integer.parse(op_str) do
        {num, ""} when num >= 1 and num <= length(recursos) ->
          {recurso_elegido, _} = Enum.at(indexed, num - 1)
          {:ok, recurso_elegido}

        _ ->
          {:error, "Selección de recurso inválida."}
      end
    end
  end

  defp seleccionar_categoria_recurso do
    cats = ["Hidratación", "Alimentación", "Salud / Medicamentos", "Refugio / Abrigo", "Herramientas"]
    IO.puts("\n--- SELECCIONE LA CATEGORÍA DEL RECURSO ---")
    indexed = Enum.with_index(cats, 1)
    Enum.each(indexed, fn {cat, idx} -> IO.puts("  #{idx}. #{cat}") end)

    op_str = IO.gets("Seleccione (1-#{length(cats)}): ") |> String.trim()
    case Integer.parse(op_str) do
      {num, ""} when num >= 1 and num <= length(cats) ->
        {:ok, Enum.at(cats, num - 1)}
      _ ->
        {:ok, "General"}
    end
  end

  defp seleccionar_especie do
    IO.puts("\n--- SELECCIONE LA ESPECIE DE LA MASCOTA ---")
    IO.puts("  1. Perro")
    IO.puts("  2. Gato")
    IO.puts("  3. Otro")
    case IO.gets("Seleccione (1-3): ") |> String.trim() do
      "1" -> {:ok, "Perro"}
      "2" -> {:ok, "Gato"}
      _   -> {:ok, "Otro"}
    end
  end

  defp seleccionar_tamano do
    IO.puts("\n--- SELECCIONE EL TAMAÑO ---")
    IO.puts("  1. Grande")
    IO.puts("  2. Mediano")
    IO.puts("  3. Pequeño")
    case IO.gets("Seleccione (1-3): ") |> String.trim() do
      "1" -> {:ok, "grande"}
      "2" -> {:ok, "mediano"}
      _   -> {:ok, "pequeno"}
    end
  end

  # -------------------------------------------------------------------
  # PUERTA DE AUTENTICACIÓN OBLIGATORIA
  # -------------------------------------------------------------------

  defp menu_autenticacion(estado_app) do
    IO.puts("""
    =====================================================================
    ACCESO RESTRINGIDO | AUTENTICACIÓN DE USUARIO REQUERIDA
    =====================================================================
    1. Iniciar Sesión (Login)
    2. Registrar Nuevo Usuario (Sign Up)
    3. Salir del Sistema
    """)

    opcion = IO.gets("Seleccione una opción (1-3): ") |> String.trim()

    case opcion do
      "1" -> iniciar_sesion(estado_app)
      "2" -> registrar_usuario_menu(estado_app)
      "3" -> IO.puts("\nSaliendo del sistema...")
      _   ->
        IO.puts("\n[ERROR] Opción inválida.")
        menu_autenticacion(estado_app)
    end
  end

  defp iniciar_sesion(estado_app) do
    IO.puts("\n--- INICIO DE SESIÓN ---")
    username = IO.gets("Username (ej: jeison): ") |> String.trim() |> String.downcase()
    password = IO.gets("Contraseña: ") |> String.trim()

    case Emergencia.ServidorRecursos.autenticar_usuario(username, password) do
      {:ok, %Usuario{} = u} ->
        IO.puts("\n[ACCESO CONCEDIDO] Bienvenido/a #{u.nombre} [Rol: #{u.tipo}]")
        menu_operaciones(%{estado_app | usuario: u})

      {:error, motivo} ->
        IO.puts("\n[ACCESO DENEGADO] #{motivo}")
        menu_autenticacion(estado_app)
    end
  end

  defp registrar_usuario_menu(estado_app) do
    IO.puts("\n--- REGISTRO DE NUEVO USUARIO ---")
    username = IO.gets("Elija Username: ") |> String.trim() |> String.downcase()
    password = IO.gets("Elija Contraseña: ") |> String.trim()
    nombre = IO.gets("Nombre Completo: ") |> String.trim()

    IO.puts("\n--- SELECCIONE EL ROL DEL USUARIO ---")
    IO.puts("  1. Ciudadano")
    IO.puts("  2. Voluntario")
    IO.puts("  3. Coordinador")
    tipo_str = case IO.gets("Seleccione (1-3): ") |> String.trim() do
      "1" -> "ciudadano"
      "2" -> "voluntario"
      _   -> "coordinador"
    end

    {:ok, zona_obj} = seleccionar_zona()

    case Usuario.nuevo(username, password, nombre, tipo_str, zona_obj.nombre) do
      {:ok, nuevo_u} ->
        case Emergencia.ServidorRecursos.registrar_usuario(nuevo_u) do
          {:ok, u_reg} ->
            Emergencia.Persistencia.guardar_usuarios(Emergencia.ServidorRecursos.consultar_usuarios())
            IO.puts("\n[ÉXITO] Usuario '#{u_reg.username}' registrado correctamente. Ahora puede iniciar sesión.")
            menu_autenticacion(estado_app)

          {:error, err} ->
            IO.puts("\n[ERROR] #{err}")
            menu_autenticacion(estado_app)
        end

      {:error, err} ->
        IO.puts("\n[ERROR] #{err}")
        menu_autenticacion(estado_app)
    end
  end

  # -------------------------------------------------------------------
  # MENÚ PRINCIPAL DE OPERACIONES (INTUITIVO Y GUIADO)
  # -------------------------------------------------------------------

  defp menu_operaciones(estado_app) do
    u = estado_app.usuario

    IO.puts("""
    ---------------------------------------------------------------------
    MENÚ PRINCIPAL | Usuario: #{u.nombre} [#{u.tipo}] | Zona: #{u.zona_principal}
    ---------------------------------------------------------------------
    1. Ver Zonas de la Ciudad y Afectación
    2. Consultar Recursos (Inventario en Tiempo Real)
    3. Asignar Recurso a Emergencia (Transacción Atómica Auditada)
    4. Registrar Nuevo Recurso en Inventario
    5. Ver y Gestionar Albergues / Centros de Acopio (Cupos)
    6. Registrar Necesidad de Emergencia en una Zona
    7. Registrar y Buscar Mascotas (Algoritmo de Matching)
    8. Guardar Estado Completo en Disco (.txt)
    9. Ver Bitácora de Transacciones / Auditoría (.txt)
    10. Cerrar Sesión (Cerrar #{u.username})
    11. Salir del Sistema
    """)

    opcion = IO.gets("Seleccione una opción (1-11): ") |> String.trim()

    case opcion do
      "1" -> consultar_zonas_menu(estado_app)
      "2" -> consultar_recursos_menu(estado_app)
      "3" -> asignar_recurso_menu(estado_app)
      "4" -> registrar_recurso_menu(estado_app)
      "5" -> albergues_menu(estado_app)
      "6" -> necesidad_menu(estado_app)
      "7" -> mascotas_menu(estado_app)
      "8" -> guardar_menu(estado_app)
      "9" -> ver_bitacora_menu(estado_app)
      "10" ->
        IO.puts("\n[SESIÓN CERRADA] Sesión de #{u.nombre} finalizada.\n")
        menu_autenticacion(%{estado_app | usuario: nil})
      "11" -> IO.puts("\n¡Gracias por utilizar el Sistema de Gestión de Emergencias!")
      _   ->
        IO.puts("\nOpción inválida. Intente de nuevo.")
        menu_operaciones(estado_app)
    end
  end

  # --- VISTAS Y MENÚS INTUITIVOS ---

  defp consultar_zonas_menu(estado_app) do
    zonas = Emergencia.ServidorRecursos.consultar_zonas() |> Enum.sort_by (& &1.codigo)
    IO.puts("\n=== ZONAS GEOGRÁFICAS DE LA CIUDAD Y AFECTACIÓN ===")
    Enum.each(zonas, fn z ->
      IO.puts("• [#{z.codigo}] #{z.nombre} | Nivel: :#{z.nivel_afectacion} | Afectados estimados: #{z.personas_afectadas} personas")
    end)
    menu_operaciones(estado_app)
  end

  defp consultar_recursos_menu(estado_app) do
    recursos = Emergencia.ServidorRecursos.consultar_recursos() |> Enum.sort_by(& &1.codigo)
    IO.puts("\n=== INVENTARIO DE RECURSOS EN TIEMPO REAL ===")
    if recursos == [] do
      IO.puts("No hay recursos registrados.")
    else
      Enum.each(recursos, fn r ->
        IO.puts("• [#{r.codigo}] #{r.nombre} (#{r.categoria}) | Stock: #{r.cantidad} #{r.unidad} | Ubicación: #{r.ubicacion} | Mod.: #{r.ultimo_modificador}")
      end)
    end
    menu_operaciones(estado_app)
  end

  defp asignar_recurso_menu(estado_app) do
    u = estado_app.usuario

    case seleccionar_recurso_menu() do
      {:ok, recurso_elegido} ->
        IO.puts("\nHas seleccionado: [#{recurso_elegido.codigo}] #{recurso_elegido.nombre} (Stock disponible: #{recurso_elegido.cantidad} #{recurso_elegido.unidad})")
        cant_str = IO.gets("Ingrese la cantidad a solicitar: ") |> String.trim()

        case Integer.parse(cant_str) do
          {cant, ""} when cant > 0 ->
            case Emergencia.ServidorRecursos.asignar_recurso(recurso_elegido.codigo, cant, u.nombre) do
              {:ok, r} ->
                Emergencia.Persistencia.guardar_recursos(Emergencia.ServidorRecursos.consultar_recursos())
                IO.puts("\n[ÉXITO AUDITADO] Solicitud procesada por #{u.nombre}. Stock restante de '#{r.nombre}': #{r.cantidad} #{r.unidad}")

              {:error, err} ->
                IO.puts("\n[RECHAZADO AUDITADO] #{err}")
            end

          _ ->
            IO.puts("\n[ERROR] Cantidad debe ser un número entero positivo.")
        end

      {:error, err} ->
        IO.puts("\n[ERROR] #{err}")
    end

    menu_operaciones(estado_app)
  end

  defp registrar_recurso_menu(estado_app) do
    u = estado_app.usuario
    IO.puts("\n--- REGISTRAR NUEVO RECURSO EN INVENTARIO ---")
    cod = "R0" <> to_string(length(Emergencia.ServidorRecursos.consultar_recursos()) + 1)
    nom = IO.gets("Nombre del recurso (ej: Mantas térmicas): ") |> String.trim()

    {:ok, cat} = seleccionar_categoria_recurso()
    cant_str = IO.gets("Cantidad inicial: ") |> String.trim()
    uni = IO.gets("Unidad de medida (cajas, litros, paquetes): ") |> String.trim()

    IO.puts("\n--- SELECCIONE EL CENTRO DE ACOPIO DE UBICACIÓN ---")
    {:ok, albergue_ub} = seleccionar_albergue_menu()

    with {cant, ""} <- Integer.parse(cant_str),
         {:ok, r} <- Recurso.nuevo(cod, nom, cat, cant, uni, albergue_ub.nombre, u.nombre) do
      Emergencia.ServidorRecursos.registrar_recurso(r, u.nombre)
      Emergencia.Persistencia.guardar_recursos(Emergencia.ServidorRecursos.consultar_recursos())
      IO.puts("\n[ÉXITO] Recurso '#{r.nombre}' registrado en '#{albergue_ub.nombre}' a nombre de #{u.nombre}.")
    else
      {:error, err} -> IO.puts("\n[ERROR] #{err}")
      _ -> IO.puts("\n[ERROR] Cantidad debe ser número entero positivo.")
    end

    menu_operaciones(estado_app)
  end

  defp albergues_menu(estado_app) do
    u = estado_app.usuario
    albergues = Emergencia.ServidorRecursos.consultar_albergues() |> Enum.sort_by(& &1.codigo)

    IO.puts("\n=== CENTROS DE ACOPIO Y ALBERGUES DE LA CIUDAD ===")
    Enum.each(albergues, fn a ->
      IO.puts("• [#{a.codigo}] #{a.nombre} (Zona: #{a.zona_codigo}) | Ocupación: #{a.ocupacion_actual}/#{a.capacidad_maxima} personas")
    end)

    IO.puts("\n--- OPCIONES DE GESTIÓN DE ALBERGUES ---")
    IO.puts("  1. Ingresar personas a un albergue existente")
    IO.puts("  2. Crear nuevo albergue / centro de acopio")
    IO.puts("  3. Volver al menú principal")

    op = IO.gets("Seleccione una opción (1-3): ") |> String.trim()

    case op do
      "1" ->
        case seleccionar_albergue_menu() do
          {:ok, a_elegido} ->
            IO.puts("\nHas seleccionado: [#{a_elegido.codigo}] #{a_elegido.nombre} (Cupo disponible: #{a_elegido.capacidad_maxima - a_elegido.ocupacion_actual})")
            cant_str = IO.gets("Cantidad de personas a ingresar: ") |> String.trim()

            with {cant, ""} <- Integer.parse(cant_str),
                 {:ok, a_act} <- Emergencia.ServidorRecursos.ingresar_albergue(a_elegido.codigo, cant, u.nombre) do
              Emergencia.Persistencia.guardar_albergues(Emergencia.ServidorRecursos.consultar_albergues())
              IO.puts("\n[ÉXITO AUDITADO] Ingreso registrado por #{u.nombre}. Nueva ocupación en '#{a_act.nombre}': #{a_act.ocupacion_actual}/#{a_act.capacidad_maxima}")
            else
              {:error, err} -> IO.puts("\n[RECHAZADO AUDITADO] #{err}")
              _ -> IO.puts("\n[ERROR] Cantidad inválida.")
            end

          {:error, err} ->
            IO.puts("\n[ERROR] #{err}")
        end

      "2" ->
        cod = "A0" <> to_string(length(albergues) + 1)
        nom = IO.gets("Nombre del nuevo albergue/acopio: ") |> String.trim()
        {:ok, zona_sel} = seleccionar_zona()
        cap_str = IO.gets("Capacidad máxima de personas: ") |> String.trim()

        with {cap, ""} <- Integer.parse(cap_str),
             {:ok, nuevo_a} <- Albergue.nuevo(cod, nom, zona_sel.codigo, cap, u.nombre) do
          Emergencia.ServidorRecursos.registrar_albergue(nuevo_a, u.nombre)
          Emergencia.Persistencia.guardar_albergues(Emergencia.ServidorRecursos.consultar_albergues())
          IO.puts("\n[ÉXITO] Albergue '#{nuevo_a.nombre}' en #{zona_sel.nombre} creado a nombre de #{u.nombre}.")
        else
          {:error, err} -> IO.puts("\n[ERROR] #{err}")
          _ -> IO.puts("\n[ERROR] Capacidad debe ser número entero positivo.")
        end

      _ -> :ok
    end

    menu_operaciones(estado_app)
  end

  defp necesidad_menu(estado_app) do
    u = estado_app.usuario
    id = "N00" <> to_string(:rand.uniform(99))

    IO.puts("\n--- REGISTRAR NECESIDAD DE EMERGENCIA ---")
    IO.puts("Seleccione el tipo de necesidad:")
    IO.puts("  1. Agua / Hidratación")
    IO.puts("  2. Comida / Víveres")
    IO.puts("  3. Medicinas / Atencion Médica")
    IO.puts("  4. Refugio / Carpas")

    tipo = case IO.gets("Seleccione (1-4): ") |> String.trim() do
      "1" -> "agua"
      "2" -> "comida"
      "3" -> "medicinas"
      _   -> "refugio"
    end

    cant_str = IO.gets("Cantidad requerida: ") |> String.trim()
    {:ok, zona_sel} = seleccionar_zona()
    desc = IO.gets("Descripción o detalle de la necesidad: ") |> String.trim()

    with {cant, ""} <- Integer.parse(cant_str),
         {:ok, n} <- Necesidad.nueva(id, tipo, cant, :alta, zona_sel.codigo, u.nombre, desc, u.nombre) do
      Emergencia.ServidorRecursos.registrar_necesidad(n)
      Emergencia.Persistencia.guardar_necesidades(Emergencia.ServidorRecursos.consultar_necesidades())
      IO.puts("\n[ÉXITO AUDITADO] Necesidad '#{n.id}' (#{n.tipo}) registrada en #{zona_sel.nombre} a nombre de #{u.nombre}.")
    else
      {:error, err} -> IO.puts("\n[ERROR] #{err}")
      _ -> IO.puts("\n[ERROR] Datos de entrada incorrectos.")
    end

    menu_operaciones(estado_app)
  end

  defp mascotas_menu(estado_app) do
    u = estado_app.usuario
    IO.puts("\n=== GESTIÓN Y MATCHING DE MASCOTAS ===")
    IO.puts("  1. Registrar Mascota Perdida")
    IO.puts("  2. Registrar Mascota Encontrada")
    IO.puts("  3. Buscar Coincidencias Automáticas (Matching)")
    op = IO.gets("Seleccione una opción (1-3): ") |> String.trim()

    case op do
      "1" ->
        id = "M00" <> to_string(:rand.uniform(99))
        {:ok, esp} = seleccionar_especie()
        nom = IO.gets("Nombre de la mascota: ") |> String.trim()
        col = IO.gets("Color principal (ej: negro, blanco, café): ") |> String.trim()
        {:ok, tam} = seleccionar_tamano()
        {:ok, zona_sel} = seleccionar_zona()
        cont = IO.gets("Teléfono o datos de contacto: ") |> String.trim()
        desc = IO.gets("Rasgos distintivos (ej: collar rojo, mancha en oreja): ") |> String.trim()

        {:ok, m} = Mascota.nueva(id, :perdida, esp, nom, desc, col, tam, zona_sel.codigo, cont, u.nombre)
        nuevas_mascotas = [m | estado_app.mascotas]
        Emergencia.Persistencia.registrar_auditoria(u.nombre, "REGISTRO_MASCOTA_PERDIDA", "ID: #{m.id}, Nombre: #{m.nombre}, Especie: #{m.especie}")
        IO.puts("\n[OK] Mascota perdida registrada con ID '#{m.id}' en #{zona_sel.nombre} por #{u.nombre}.")
        menu_operaciones(%{estado_app | mascotas: nuevas_mascotas})

      "2" ->
        id = "M00" <> to_string(:rand.uniform(99))
        {:ok, esp} = seleccionar_especie()
        col = IO.gets("Color principal: ") |> String.trim()
        {:ok, tam} = seleccionar_tamano()
        {:ok, zona_sel} = seleccionar_zona()
        cont = IO.gets("Teléfono de quien la encontró: ") |> String.trim()
        desc = IO.gets("Lugar o rasgos distintivos: ") |> String.trim()

        {:ok, m} = Mascota.nueva(id, :encontrada, esp, "Sin nombre", desc, col, tam, zona_sel.codigo, cont, u.nombre)
        nuevas_mascotas = [m | estado_app.mascotas]
        Emergencia.Persistencia.registrar_auditoria(u.nombre, "REGISTRO_MASCOTA_ENCONTRADA", "ID: #{m.id}, Especie: #{m.especie}")
        IO.puts("\n[OK] Mascota encontrada registrada con ID '#{m.id}' en #{zona_sel.nombre} por #{u.nombre}.")
        menu_operaciones(%{estado_app | mascotas: nuevas_mascotas})

      "3" ->
        perdidas = Enum.filter(estado_app.mascotas, &(&1.tipo_reporte == :perdida))
        if perdidas == [] do
          IO.puts("\nNo hay mascotas perdidas registradas en esta sesión para buscar coincidencias.")
        else
          m_ref = hd(perdidas)
          coincidencias = Emergencia.MatchingMascotas.encontrar_coincidencias(m_ref, estado_app.mascotas)

          IO.puts("\n--- RESULTADOS DE MATCHING PARA '#{m_ref.nombre}' (#{m_ref.especie}, #{m_ref.color}) ---")
          if coincidencias == [] do
            IO.puts("No se encontraron coincidencias suficientes por encima del umbral.")
          else
            Enum.each(coincidencias, fn {m, score} ->
              IO.puts("• ID #{m.id} (#{m.especie}, #{m.color}) | Contacto: #{m.contacto} | Registrado por: #{m.registrado_por} | Coincidencia: #{score}%")
            end)
          end
        end
        menu_operaciones(estado_app)

      _ -> menu_operaciones(estado_app)
    end
  end

  defp guardar_menu(estado_app) do
    u = estado_app.usuario
    zonas = Emergencia.ServidorRecursos.consultar_zonas()
    usuarios = Emergencia.ServidorRecursos.consultar_usuarios()
    recursos = Emergencia.ServidorRecursos.consultar_recursos()
    albergues = Emergencia.ServidorRecursos.consultar_albergues()
    necesidades = Emergencia.ServidorRecursos.consultar_necesidades()

    Emergencia.Persistencia.guardar_zonas(zonas)
    Emergencia.Persistencia.guardar_usuarios(usuarios)
    Emergencia.Persistencia.guardar_recursos(recursos)
    Emergencia.Persistencia.guardar_albergues(albergues)
    Emergencia.Persistencia.guardar_necesidades(necesidades)

    Emergencia.Persistencia.registrar_auditoria(u.nombre, "GUARDAR_ESTADO", "Guardado manual del sistema en disco .txt")

    IO.puts("\n[PERSISTENCIA ÉXITO] Sincronización completa en zonas.txt, usuarios.txt, recursos.txt, albergues.txt y necesidades.txt.")
    menu_operaciones(estado_app)
  end

  defp ver_bitacora_menu(estado_app) do
    ruta = "bitacora_transacciones.txt"

    IO.puts("\n=== BITÁCORA DE TRANSACCIONES Y AUDITORÍA (HISTORIAL EN DISCO) ===")
    if File.exists?(ruta) do
      File.stream!(ruta)
      |> Stream.map(&String.trim/1)
      |> Enum.each(&IO.puts/1)
    else
      IO.puts("La bitácora aún no contiene registros.")
    end

    menu_operaciones(estado_app)
  end
end

# Iniciar la aplicación
SistemaEmergencia.iniciar()
