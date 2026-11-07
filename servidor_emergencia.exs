# =====================================================================
# UNIVERSIDAD DEL QUINDÍO - PROGRAMACIÓN III (PROYECTO FINAL)
# Autor: Jeison López
# =====================================================================

Code.require_file(Path.expand("estructuras.exs", __DIR__))
Code.require_file(Path.expand("persistencia.exs", __DIR__))

defmodule Emergencia.ServidorRecursos do
  @moduledoc """
  GenServer centralizado para la gestión concurrente, atómica y segura de:
  1. Zonas Geográficas y su nivel de afectación.
  2. Autenticación y Registro de Usuarios.
  3. Recursos e Inventarios con auditoría del solicitante.
  4. Albergues con control estricto de capacidad.
  5. Necesidades vinculadas a usuarios.
  """
  use GenServer

  # -------------------------------------------------------------------
  # CLIENT API (Invocaciones públicas)
  # -------------------------------------------------------------------

  def start_link(opts \\ []) do
    nombre = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, :ok, name: nombre)
  end

  # --- GESTIÓN DE ZONAS ---

  def registrar_zona(zona), do: registrar_zona(__MODULE__, zona)
  def registrar_zona(servidor, %Zona{} = zona) do
    GenServer.call(servidor, {:registrar_zona, zona})
  end

  def consultar_zonas(servidor \\ __MODULE__) do
    GenServer.call(servidor, :consultar_zonas)
  end

  # --- AUTENTICACIÓN Y USUARIOS ---

  def registrar_usuario(usuario), do: registrar_usuario(__MODULE__, usuario)
  def registrar_usuario(servidor, %Usuario{} = usuario) do
    GenServer.call(servidor, {:registrar_usuario, usuario})
  end

  def autenticar_usuario(username, password), do: autenticar_usuario(__MODULE__, username, password)
  def autenticar_usuario(servidor, username, password) do
    GenServer.call(servidor, {:autenticar_usuario, username, password})
  end

  def consultar_usuarios(servidor \\ __MODULE__) do
    GenServer.call(servidor, :consultar_usuarios)
  end

  # --- GESTIÓN DE RECURSOS ---

  def registrar_recurso(recurso, usuario_nombre \\ "Sistema")
  def registrar_recurso(%Recurso{} = recurso, usuario_nombre) when is_binary(usuario_nombre) do
    registrar_recurso(__MODULE__, recurso, usuario_nombre)
  end
  def registrar_recurso(servidor, %Recurso{} = recurso, usuario_nombre) do
    GenServer.call(servidor, {:registrar_recurso, recurso, usuario_nombre})
  end

  def consultar_recursos(servidor \\ __MODULE__) do
    GenServer.call(servidor, :consultar_recursos)
  end

  def asignar_recurso(codigo_recurso, cantidad_solicitada, usuario_nombre) do
    asignar_recurso(__MODULE__, codigo_recurso, cantidad_solicitada, usuario_nombre)
  end
  def asignar_recurso(servidor, codigo_recurso, cantidad_solicitada, usuario_nombre) do
    GenServer.call(servidor, {:asignar_recurso, codigo_recurso, cantidad_solicitada, usuario_nombre})
  end

  # --- GESTIÓN DE ALBERGUES ---

  def registrar_albergue(albergue, usuario_nombre \\ "Sistema")
  def registrar_albergue(%Albergue{} = albergue, usuario_nombre) when is_binary(usuario_nombre) do
    registrar_albergue(__MODULE__, albergue, usuario_nombre)
  end
  def registrar_albergue(servidor, %Albergue{} = albergue, usuario_nombre) do
    GenServer.call(servidor, {:registrar_albergue, albergue, usuario_nombre})
  end

  def consultar_albergues(servidor \\ __MODULE__) do
    GenServer.call(servidor, :consultar_albergues)
  end

  def ingresar_albergue(codigo_albergue, cantidad_personas, usuario_nombre) do
    ingresar_albergue(__MODULE__, codigo_albergue, cantidad_personas, usuario_nombre)
  end
  def ingresar_albergue(servidor, codigo_albergue, cantidad_personas, usuario_nombre) do
    GenServer.call(servidor, {:ingresar_albergue, codigo_albergue, cantidad_personas, usuario_nombre})
  end

  # --- GESTIÓN DE NECESIDADES ---

  def registrar_necesidad(necesidad), do: registrar_necesidad(__MODULE__, necesidad)
  def registrar_necesidad(servidor, %Necesidad{} = necesidad) do
    GenServer.call(servidor, {:registrar_necesidad, necesidad})
  end

  def consultar_necesidades(servidor \\ __MODULE__) do
    GenServer.call(servidor, :consultar_necesidades)
  end

  def cambiar_estado_necesidad(id_necesidad, nuevo_estado, responsable, usuario_nombre) do
    cambiar_estado_necesidad(__MODULE__, id_necesidad, nuevo_estado, responsable, usuario_nombre)
  end
  def cambiar_estado_necesidad(servidor, id_necesidad, nuevo_estado, responsable, usuario_nombre) do
    GenServer.call(servidor, {:cambiar_estado_necesidad, id_necesidad, nuevo_estado, responsable, usuario_nombre})
  end

  # -------------------------------------------------------------------
  # SERVER CALLBACKS (Manejo interno de estado)
  # -------------------------------------------------------------------

  @impl true
  def init(:ok) do
    estado_inicial = %{
      zonas: %{},
      usuarios: %{},
      recursos: %{},
      albergues: %{},
      necesidades: %{}
    }
    {:ok, estado_inicial}
  end

  # --- Handlers de Zonas ---

  @impl true
  def handle_call({:registrar_zona, %Zona{} = zona}, _from, estado) do
    nuevo_mapa = Map.put(estado.zonas, zona.codigo, zona)
    {:reply, {:ok, zona}, %{estado | zonas: nuevo_mapa}}
  end

  @impl true
  def handle_call(:consultar_zonas, _from, estado) do
    {:reply, Map.values(estado.zonas), estado}
  end

  # --- Handlers de Usuarios ---

  @impl true
  def handle_call({:registrar_usuario, %Usuario{} = usuario}, _from, estado) do
    case Map.get(estado.usuarios, usuario.username) do
      nil ->
        nuevo_mapa = Map.put(estado.usuarios, usuario.username, usuario)
        Emergencia.Persistencia.registrar_auditoria(usuario.nombre, "REGISTRO_USUARIO", "Nuevo usuario registrado [#{usuario.username}] tipo #{usuario.tipo}")
        {:reply, {:ok, usuario}, %{estado | usuarios: nuevo_mapa}}

      _existente ->
        {:reply, {:error, "El usuario con username '#{usuario.username}' ya existe"}, estado}
    end
  end

  @impl true
  def handle_call({:autenticar_usuario, username, password}, _from, estado) do
    case Map.get(estado.usuarios, username) do
      nil ->
        {:reply, {:error, "Usuario no encontrado"}, estado}

      %Usuario{password: ^password, activo: true} = u ->
        Emergencia.Persistencia.registrar_auditoria(u.nombre, "LOGIN_EXITOSO", "Inicio de sesión correcto [#{username}]")
        {:reply, {:ok, u}, estado}

      %Usuario{password: _otra} ->
        Emergencia.Persistencia.registrar_auditoria(username, "LOGIN_FALLIDO", "Contraseña incorrecta para usuario [#{username}]")
        {:reply, {:error, "Contraseña incorrecta"}, estado}
    end
  end

  @impl true
  def handle_call(:consultar_usuarios, _from, estado) do
    {:reply, Map.values(estado.usuarios), estado}
  end

  # --- Handlers de Recursos ---

  @impl true
  def handle_call({:registrar_recurso, %Recurso{} = recurso, usuario_nombre}, _from, estado) do
    recurso_con_autor = %{recurso | registrado_por: usuario_nombre, ultimo_modificador: usuario_nombre}
    nuevo_mapa = Map.put(estado.recursos, recurso.codigo, recurso_con_autor)
    Emergencia.Persistencia.registrar_auditoria(usuario_nombre, "REGISTRO_RECURSO", "Registrado recurso #{recurso.codigo} (#{recurso.nombre}) cantidad #{recurso.cantidad}")
    {:reply, {:ok, recurso_con_autor}, %{estado | recursos: nuevo_mapa}}
  end

  @impl true
  def handle_call(:consultar_recursos, _from, estado) do
    {:reply, Map.values(estado.recursos), estado}
  end

  @impl true
  def handle_call({:asignar_recurso, codigo, cantidad, usuario_nombre}, _from, estado) do
    case Map.get(estado.recursos, codigo) do
      nil ->
        Emergencia.Persistencia.registrar_auditoria(usuario_nombre, "ASIGNACION_RECURSO_FALLIDA", "Recurso #{codigo} no existe")
        {:reply, {:error, "El recurso con código '#{codigo}' no existe"}, estado}

      %Recurso{cantidad: disponible} when disponible < cantidad ->
        Emergencia.Persistencia.registrar_auditoria(usuario_nombre, "ASIGNACION_RECURSO_RECHAZADA", "Stock insuficiente de #{codigo}. Solicito: #{cantidad}, Disponible: #{disponible}")
        {:reply, {:error, "Stock insuficiente. Disponible: #{disponible}, solicitado: #{cantidad}"}, estado}

      %Recurso{} = recurso ->
        recurso_actualizado = %{recurso | cantidad: recurso.cantidad - cantidad, ultimo_modificador: usuario_nombre}
        nuevo_mapa = Map.put(estado.recursos, codigo, recurso_actualizado)
        Emergencia.Persistencia.registrar_auditoria(usuario_nombre, "ASIGNACION_RECURSO_EXITOSA", "Asignados #{cantidad} de #{recurso.nombre} (#{codigo}). Quedan: #{recurso_actualizado.cantidad}")
        {:reply, {:ok, recurso_actualizado}, %{estado | recursos: nuevo_mapa}}
    end
  end

  # --- Handlers de Albergues ---

  @impl true
  def handle_call({:registrar_albergue, %Albergue{} = albergue, usuario_nombre}, _from, estado) do
    albergue_con_autor = %{albergue | registrado_por: usuario_nombre, ultimo_modificador: usuario_nombre}
    nuevo_mapa = Map.put(estado.albergues, albergue.codigo, albergue_con_autor)
    Emergencia.Persistencia.registrar_auditoria(usuario_nombre, "REGISTRO_ALBERGUE", "Registrado albergue #{albergue.codigo} (#{albergue.nombre}) capacidad #{albergue.capacidad_maxima}")
    {:reply, {:ok, albergue_con_autor}, %{estado | albergues: nuevo_mapa}}
  end

  @impl true
  def handle_call(:consultar_albergues, _from, estado) do
    {:reply, Map.values(estado.albergues), estado}
  end

  @impl true
  def handle_call({:ingresar_albergue, codigo, cantidad, usuario_nombre}, _from, estado) do
    case Map.get(estado.albergues, codigo) do
      nil ->
        Emergencia.Persistencia.registrar_auditoria(usuario_nombre, "INGRESO_ALBERGUE_FALLIDO", "Albergue #{codigo} no existe")
        {:reply, {:error, "El albergue con código '#{codigo}' no existe"}, estado}

      %Albergue{ocupacion_actual: ocupacion, capacidad_maxima: max} when ocupacion + cantidad > max ->
        disponible = max - ocupacion
        Emergencia.Persistencia.registrar_auditoria(usuario_nombre, "INGRESO_ALBERGUE_RECHAZADO", "Capacidad excedida en #{codigo}. Intento ingresar: #{cantidad}, Espacio: #{disponible}")
        {:reply, {:error, "Capacidad excedida en albergue '#{codigo}'. Espacio disponible: #{disponible}"}, estado}

      %Albergue{} = albergue ->
        albergue_actualizado = %{albergue | ocupacion_actual: albergue.ocupacion_actual + cantidad, ultimo_modificador: usuario_nombre}
        nuevo_mapa = Map.put(estado.albergues, codigo, albergue_actualizado)
        Emergencia.Persistencia.registrar_auditoria(usuario_nombre, "INGRESO_ALBERGUE_EXITOSO", "Ingresadas #{cantidad} personas a albergue #{albergue.nombre} (#{codigo}). Ocupacion: #{albergue_actualizado.ocupacion_actual}/#{albergue_actualizado.capacidad_maxima}")
        {:reply, {:ok, albergue_actualizado}, %{estado | albergues: nuevo_mapa}}
    end
  end

  # --- Handlers de Necesidades ---

  @impl true
  def handle_call({:registrar_necesidad, %Necesidad{} = necesidad}, _from, estado) do
    nuevo_mapa = Map.put(estado.necesidades, necesidad.id, necesidad)
    Emergencia.Persistencia.registrar_auditoria(necesidad.solicitado_por, "REGISTRO_NECESIDAD", "Registrada necesidad #{necesidad.id} (#{necesidad.tipo}) cantidad #{necesidad.cantidad} en zona #{necesidad.zona_codigo}")
    {:reply, {:ok, necesidad}, %{estado | necesidades: nuevo_mapa}}
  end

  @impl true
  def handle_call(:consultar_necesidades, _from, estado) do
    {:reply, Map.values(estado.necesidades), estado}
  end

  @impl true
  def handle_call({:cambiar_estado_necesidad, id, nuevo_estado, responsable, usuario_nombre}, _from, estado) do
    case Map.get(estado.necesidades, id) do
      nil ->
        {:reply, {:error, "La necesidad con ID '#{id}' no existe"}, estado}

      %Necesidad{} = necesidad ->
        necesidad_actualizada = %{necesidad | estado: nuevo_estado, responsable: responsable}
        nuevo_mapa = Map.put(estado.necesidades, id, necesidad_actualizada)
        Emergencia.Persistencia.registrar_auditoria(usuario_nombre, "CAMBIO_ESTADO_NECESIDAD", "Necesidad #{id} cambio a estado :#{nuevo_estado} (Responsable: #{responsable})")
        {:reply, {:ok, necesidad_actualizada}, %{estado | necesidades: nuevo_mapa}}
    end
  end
end
