# =====================================================================
# UNIVERSIDAD DEL QUINDÍO - PROGRAMACIÓN III (PROYECTO FINAL)
# Autor: Jeison López
# FASE 5: SISTEMA CENTRAL E INTERFAZ CLI (CON CONTROL DE ACCESO Y AUDITORÍA)
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
  - Puerta de enlace de Autenticación Obligatoria (Login / Registro).
  - Auditoría de peticiones asociada al usuario autenticado.
  - Sincronización continua con archivos planos (.txt).
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

    # 3. Mostrar Puerta de Entrada (Acceso Obligatorio)
    menu_autenticacion(%{usuario: nil, mascotas: []})
  end

  defp cargar_datos_disco do
    IO.puts("[Persistencia] Cargando datos guardados en archivos planos...")

    # Cargar usuarios
    {:ok, usuarios} = Emergencia.Persistencia.cargar_usuarios()

    # Si no hay usuarios en usuarios.txt, creamos una cuenta inicial por defecto
    usuarios_finales =
      if usuarios == [] do
        {:ok, admin} = Usuario.nuevo("jeison", "1234", "Jeison López", :coordinador, "Zona Centro")
        [admin]
      else
        usuarios
      end

    Enum.each(usuarios_finales, &Emergencia.ServidorRecursos.registrar_usuario/1)
    Emergencia.Persistencia.guardar_usuarios(Emergencia.ServidorRecursos.consultar_usuarios())

    # Cargar recursos
    {:ok, recursos} = Emergencia.Persistencia.cargar_recursos()
    Enum.each(recursos, fn r -> Emergencia.ServidorRecursos.registrar_recurso(r, r.registrado_por) end)

    # Cargar albergues
    {:ok, albergues} = Emergencia.Persistencia.cargar_albergues()
    Enum.each(albergues, fn a -> Emergencia.ServidorRecursos.registrar_albergue(a, a.registrado_por) end)

    # Cargar necesidades
    {:ok, necesidades} = Emergencia.Persistencia.cargar_necesidades()
    Enum.each(necesidades, &Emergencia.ServidorRecursos.registrar_necesidad/1)

    num_u = Enum.count(Emergencia.ServidorRecursos.consultar_usuarios())
    num_r = Enum.count(recursos)
    num_a = Enum.count(albergues)
    num_n = Enum.count(necesidades)

    IO.puts("[OK] Estado cargado: #{num_u} usuario(s), #{num_r} recurso(s), #{num_a} albergue(s), #{num_n} necesidad(es).\n")
  end

  # -------------------------------------------------------------------
  # PUERTA DE AUTENTICACIÓN OBLIGATORIA (LOGIN / REGISTRO)
  # -------------------------------------------------------------------

  defp menu_autenticacion(estado_app) do
    IO.puts("""
    =====================================================================
    ACCESO RESTRINGIDO | AUTENTICACIÓN DE USUARIO REQUERIDA
    =====================================================================
    1. Iniciar Sesión (Login)
    2. Registrar Nuevo Usuario
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
    tipo = IO.gets("Rol (coordinador / voluntario / ciudadano): ") |> String.trim() |> String.downcase()
    zona = IO.gets("Zona principal: ") |> String.trim()

    case Usuario.nuevo(username, password, nombre, tipo, zona) do
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
  # MENÚ DE OPERACIONES (SOLO ACCESIBLE PARA USUARIOS AUTENTICADOS)
  # -------------------------------------------------------------------

  defp menu_operaciones(estado_app) do
    u = estado_app.usuario

    IO.puts("""
    ---------------------------------------------------------------------
    MENÚ PRINCIPAL | Usuario Autenticado: #{u.nombre} [#{u.tipo}]
    ---------------------------------------------------------------------
    1. Consultar Recursos (Inventario en Tiempo Real)
    2. Registrar Nuevo Recurso (Auditado a tu nombre)
    3. Asignar Recurso (Transacción Atómica Protegida y Auditada)
    4. Consultar y Registrar en Albergues (Control de Capacidad)
    5. Registrar Necesidad de Emergencia (Vinculada a tu usuario)
    6. Registrar y Buscar Coincidencias de Mascotas (Matching)
    7. Guardar Estado Completo en Archivos Planos (.txt)
    8. Ver Bitácora de Transacciones / Auditoría (.txt)
    9. Cerrar Sesión (Cerrar #{u.username})
    10. Salir del Sistema
    """)

    opcion = IO.gets("Seleccione una opción (1-10): ") |> String.trim()

    case opcion do
      "1" -> consultar_recursos_menu(estado_app)
      "2" -> registrar_recurso_menu(estado_app)
      "3" -> asignar_recurso_menu(estado_app)
      "4" -> albergues_menu(estado_app)
      "5" -> necesidad_menu(estado_app)
      "6" -> mascotas_menu(estado_app)
      "7" -> guardar_menu(estado_app)
      "8" -> ver_bitacora_menu(estado_app)
      "9" ->
        IO.puts("\n[SESIÓN CERRADA] Sesión de #{u.nombre} finalizada.\n")
        menu_autenticacion(%{estado_app | usuario: nil})
      "10" -> IO.puts("\n¡Gracias por utilizar el Sistema de Gestión de Emergencias!")
      _   ->
        IO.puts("\nOpción inválida. Intente de nuevo.")
        menu_operaciones(estado_app)
    end
  end

  # --- OPCIONES DEL MENÚ ---

  defp consultar_recursos_menu(estado_app) do
    recursos = Emergencia.ServidorRecursos.consultar_recursos()

    IO.puts("\n=== INVENTARIO DE RECURSOS EN TIEMPO REAL ===")
    if recursos == [] do
      IO.puts("No hay recursos registrados.")
    else
      Enum.each(recursos, fn r ->
        IO.puts("• [#{r.codigo}] #{r.nombre} | Cantidad: #{r.cantidad} #{r.unidad} | Ubicación: #{r.ubicacion} | Creado por: #{r.registrado_por} | Último mod.: #{r.ultimo_modificador}")
      end)
    end

    menu_operaciones(estado_app)
  end

  defp registrar_recurso_menu(estado_app) do
    u = estado_app.usuario
    IO.puts("\n--- REGISTRAR NUEVO RECURSO ---")
    cod = IO.gets("Código del recurso (ej: R02): ") |> String.trim()
    nom = IO.gets("Nombre del recurso: ") |> String.trim()
    cat = IO.gets("Categoría (Salud / Alimentacion / Refugio): ") |> String.trim()
    cant_str = IO.gets("Cantidad inicial: ") |> String.trim()
    uni = IO.gets("Unidad (cajas, litros, paquetes): ") |> String.trim()
    ubi = IO.gets("Ubicación de acopio: ") |> String.trim()

    with {cant, ""} <- Integer.parse(cant_str),
         {:ok, r} <- Recurso.nuevo(cod, nom, cat, cant, uni, ubi, u.nombre) do
      Emergencia.ServidorRecursos.registrar_recurso(r, u.nombre)
      Emergencia.Persistencia.guardar_recursos(Emergencia.ServidorRecursos.consultar_recursos())
      IO.puts("\n[ÉXITO] Recurso '#{r.nombre}' registrado a nombre de #{u.nombre}.")
    else
      {:error, err} -> IO.puts("\n[ERROR] #{err}")
      _ -> IO.puts("\n[ERROR] Cantidad debe ser número entero positivo.")
    end

    menu_operaciones(estado_app)
  end

  defp asignar_recurso_menu(estado_app) do
    u = estado_app.usuario
    codigo = IO.gets("Código del recurso (ej: R01): ") |> String.trim()
    cant_str = IO.gets("Cantidad a solicitar: ") |> String.trim()

    case Integer.parse(cant_str) do
      {cant, ""} when cant > 0 ->
        case Emergencia.ServidorRecursos.asignar_recurso(codigo, cant, u.nombre) do
          {:ok, r} ->
            Emergencia.Persistencia.guardar_recursos(Emergencia.ServidorRecursos.consultar_recursos())
            IO.puts("\n[ÉXITO AUDITADO] Solicitud procesada por #{u.nombre}. Stock restante de '#{r.nombre}': #{r.cantidad} #{r.unidad}")

          {:error, err} ->
            IO.puts("\n[RECHAZADO AUDITADO] #{err}")
        end

      _ ->
        IO.puts("\n[ERROR] Cantidad debe ser un número entero positivo.")
    end

    menu_operaciones(estado_app)
  end

  defp albergues_menu(estado_app) do
    u = estado_app.usuario
    albergues = Emergencia.ServidorRecursos.consultar_albergues()

    IO.puts("\n=== ESTADO DE ALBERGUES Y CAPACIDAD ===")
    if albergues == [] do
      IO.puts("No hay albergues registrados.")
    else
      Enum.each(albergues, fn a ->
        IO.puts("• [#{a.codigo}] #{a.nombre} | Ocupación: #{a.ocupacion_actual}/#{a.capacidad_maxima} | Creado por: #{a.registrado_por}")
      end)
    end

    IO.puts("\nOpciones de Albergue:")
    IO.puts("1. Ingresar personas a albergue existente")
    IO.puts("2. Registrar nuevo albergue")
    IO.puts("3. Volver al menú principal")

    op = IO.gets("Seleccione una opción: ") |> String.trim()

    case op do
      "1" ->
        cod = IO.gets("Código del albergue: ") |> String.trim()
        cant_str = IO.gets("Cantidad de personas a ingresar: ") |> String.trim()

        with {cant, ""} <- Integer.parse(cant_str),
             {:ok, a_actualizado} <- Emergencia.ServidorRecursos.ingresar_albergue(cod, cant, u.nombre) do
          Emergencia.Persistencia.guardar_albergues(Emergencia.ServidorRecursos.consultar_albergues())
          IO.puts("\n[ÉXITO AUDITADO] Ingreso registrado por #{u.nombre}. Ocupación en '#{a_actualizado.nombre}': #{a_actualizado.ocupacion_actual}/#{a_actualizado.capacidad_maxima}")
        else
          {:error, err} -> IO.puts("\n[RECHAZADO AUDITADO] #{err}")
          _ -> IO.puts("\n[ERROR] Cantidad inválida.")
        end

      "2" ->
        cod = IO.gets("Código del nuevo albergue (ej: A02): ") |> String.trim()
        nom = IO.gets("Nombre del albergue: ") |> String.trim()
        zona = IO.gets("Código de zona (ej: Z01): ") |> String.trim()
        cap_str = IO.gets("Capacidad máxima: ") |> String.trim()

        with {cap, ""} <- Integer.parse(cap_str),
             {:ok, nuevo_a} <- Albergue.nuevo(cod, nom, zona, cap, u.nombre) do
          Emergencia.ServidorRecursos.registrar_albergue(nuevo_a, u.nombre)
          Emergencia.Persistencia.guardar_albergues(Emergencia.ServidorRecursos.consultar_albergues())
          IO.puts("\n[ÉXITO] Albergue '#{nuevo_a.nombre}' registrado a nombre de #{u.nombre}.")
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
    tipo = IO.gets("Tipo de necesidad (agua, comida, medicinas, refugio): ") |> String.trim()
    cant_str = IO.gets("Cantidad: ") |> String.trim()
    zona = IO.gets("Código de zona (ej: Z01): ") |> String.trim()
    desc = IO.gets("Descripción breve: ") |> String.trim()

    with {cant, ""} <- Integer.parse(cant_str),
         {:ok, n} <- Necesidad.nueva(id, tipo, cant, :alta, zona, u.nombre, desc, u.nombre) do
      Emergencia.ServidorRecursos.registrar_necesidad(n)
      Emergencia.Persistencia.guardar_necesidades(Emergencia.ServidorRecursos.consultar_necesidades())
      IO.puts("\n[ÉXITO AUDITADO] Necesidad '#{n.id}' registrada a nombre de #{u.nombre} (Solicitante).")
    else
      {:error, err} -> IO.puts("\n[ERROR] #{err}")
      _ -> IO.puts("\n[ERROR] Datos de entrada incorrectos.")
    end

    menu_operaciones(estado_app)
  end

  defp mascotas_menu(estado_app) do
    u = estado_app.usuario
    IO.puts("\n=== GESTIÓN Y MATCHING DE MASCOTAS ===")
    op = IO.gets("1. Registrar Mascota Perdida\n2. Registrar Mascota Encontrada\n3. Buscar Coincidencias (Matching)\nOpción: ") |> String.trim()

    case op do
      "1" ->
        id = "M00" <> to_string(:rand.uniform(99))
        esp = IO.gets("Especie (Perro/Gato): ") |> String.trim()
        nom = IO.gets("Nombre: ") |> String.trim()
        col = IO.gets("Color: ") |> String.trim()
        tam = IO.gets("Tamaño (grande/mediano/pequeno): ") |> String.trim()
        zona = IO.gets("Zona: ") |> String.trim()
        cont = IO.gets("Contacto: ") |> String.trim()

        {:ok, m} = Mascota.nueva(id, :perdida, esp, nom, "Perdida tras terremoto", col, tam, zona, cont, u.nombre)
        nuevas_mascotas = [m | estado_app.mascotas]
        Emergencia.Persistencia.registrar_auditoria(u.nombre, "REGISTRO_MASCOTA_PERDIDA", "ID: #{m.id}, Nombre: #{m.nombre}, Especie: #{m.especie}")
        IO.puts("\n[OK] Mascota perdida registrada con ID '#{m.id}' por #{u.nombre}.")
        menu_operaciones(%{estado_app | mascotas: nuevas_mascotas})

      "2" ->
        id = "M00" <> to_string(:rand.uniform(99))
        esp = IO.gets("Especie (Perro/Gato): ") |> String.trim()
        col = IO.gets("Color: ") |> String.trim()
        tam = IO.gets("Tamaño (grande/mediano/pequeno): ") |> String.trim()
        zona = IO.gets("Zona: ") |> String.trim()
        cont = IO.gets("Contacto: ") |> String.trim()

        {:ok, m} = Mascota.nueva(id, :encontrada, esp, "Sin nombre", "Encontrada sola", col, tam, zona, cont, u.nombre)
        nuevas_mascotas = [m | estado_app.mascotas]
        Emergencia.Persistencia.registrar_auditoria(u.nombre, "REGISTRO_MASCOTA_ENCONTRADA", "ID: #{m.id}, Especie: #{m.especie}")
        IO.puts("\n[OK] Mascota encontrada registrada con ID '#{m.id}' por #{u.nombre}.")
        menu_operaciones(%{estado_app | mascotas: nuevas_mascotas})

      "3" ->
        perdidas = Enum.filter(estado_app.mascotas, &(&1.tipo_reporte == :perdida))
        if perdidas == [] do
          IO.puts("\nNo hay mascotas perdidas registradas para buscar coincidencias.")
        else
          m_ref = hd(perdidas)
          coincidencias = Emergencia.MatchingMascotas.encontrar_coincidencias(m_ref, estado_app.mascotas)

          IO.puts("\n--- RESULTADOS DE MATCHING PARA '#{m_ref.nombre}' (#{m_ref.especie}, #{m_ref.color}) ---")
          if coincidencias == [] do
            IO.puts("No se encontraron coincidencias por encima del umbral.")
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
    usuarios = Emergencia.ServidorRecursos.consultar_usuarios()
    recursos = Emergencia.ServidorRecursos.consultar_recursos()
    albergues = Emergencia.ServidorRecursos.consultar_albergues()
    necesidades = Emergencia.ServidorRecursos.consultar_necesidades()

    Emergencia.Persistencia.guardar_usuarios(usuarios)
    Emergencia.Persistencia.guardar_recursos(recursos)
    Emergencia.Persistencia.guardar_albergues(albergues)
    Emergencia.Persistencia.guardar_necesidades(necesidades)

    Emergencia.Persistencia.registrar_auditoria(u.nombre, "GUARDAR_ESTADO", "Guardado manual del sistema en disco .txt")

    IO.puts("\n[PERSISTENCIA ÉXITO] Todos los datos sincronizados en usuarios.txt, recursos.txt, albergues.txt y necesidades.txt.")
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
