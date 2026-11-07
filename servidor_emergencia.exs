# =====================================================================
# UNIVERSIDAD DEL QUINDÍO - PROGRAMACIÓN III (PROYECTO FINAL)
# Autor: Jeison López
# FASE 2: SERVIDOR CONCURRENTE CON GENSERVER (CORREGIDO)
# =====================================================================

Code.require_file(Path.expand("estructuras.exs", __DIR__))

defmodule Emergencia.ServidorRecursos do
  @moduledoc """
  GenServer centralizado para la gestión concurrente y atómica de:
  1. Recursos e Inventarios (evita sobreasignación de stock).
  2. Albergues (control estricto de capacidad máxima).
  3. Necesidades (transición atómica de estados: :pendiente -> :asignada -> :atendida).
  """
  use GenServer

  # -------------------------------------------------------------------
  # CLIENT API (Invocaciones públicas)
  # -------------------------------------------------------------------

  def start_link(opts \\ []) do
    nombre = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, :ok, name: nombre)
  end

  # --- GESTIÓN DE RECURSOS ---

  def registrar_recurso(recurso), do: registrar_recurso(__MODULE__, recurso)
  def registrar_recurso(servidor, %Recurso{} = recurso) do
    GenServer.call(servidor, {:registrar_recurso, recurso})
  end

  def consultar_recursos(servidor \\ __MODULE__) do
    GenServer.call(servidor, :consultar_recursos)
  end

  def asignar_recurso(codigo_recurso, cantidad_solicitada) do
    asignar_recurso(__MODULE__, codigo_recurso, cantidad_solicitada)
  end
  def asignar_recurso(servidor, codigo_recurso, cantidad_solicitada) do
    GenServer.call(servidor, {:asignar_recurso, codigo_recurso, cantidad_solicitada})
  end

  # --- GESTIÓN DE ALBERGUES ---

  def registrar_albergue(albergue), do: registrar_albergue(__MODULE__, albergue)
  def registrar_albergue(servidor, %Albergue{} = albergue) do
    GenServer.call(servidor, {:registrar_albergue, albergue})
  end

  def consultar_albergues(servidor \\ __MODULE__) do
    GenServer.call(servidor, :consultar_albergues)
  end

  def ingresar_albergue(codigo_albergue, cantidad_personas) do
    ingresar_albergue(__MODULE__, codigo_albergue, cantidad_personas)
  end
  def ingresar_albergue(servidor, codigo_albergue, cantidad_personas) do
    GenServer.call(servidor, {:ingresar_albergue, codigo_albergue, cantidad_personas})
  end

  # --- GESTIÓN DE NECESIDADES ---

  def registrar_necesidad(necesidad), do: registrar_necesidad(__MODULE__, necesidad)
  def registrar_necesidad(servidor, %Necesidad{} = necesidad) do
    GenServer.call(servidor, {:registrar_necesidad, necesidad})
  end

  def consultar_necesidades(servidor \\ __MODULE__) do
    GenServer.call(servidor, :consultar_necesidades)
  end

  def cambiar_estado_necesidad(id_necesidad, nuevo_estado, responsable \\ "") do
    cambiar_estado_necesidad(__MODULE__, id_necesidad, nuevo_estado, responsable)
  end
  def cambiar_estado_necesidad(servidor, id_necesidad, nuevo_estado, responsable) do
    GenServer.call(servidor, {:cambiar_estado_necesidad, id_necesidad, nuevo_estado, responsable})
  end

  # -------------------------------------------------------------------
  # SERVER CALLBACKS (Manejo interno de estado)
  # -------------------------------------------------------------------

  @impl true
  def init(:ok) do
    estado_inicial = %{
      recursos: %{},
      albergues: %{},
      necesidades: %{}
    }
    {:ok, estado_inicial}
  end

  # --- Handlers de Recursos ---

  @impl true
  def handle_call({:registrar_recurso, %Recurso{} = recurso}, _from, estado) do
    nuevo_mapa = Map.put(estado.recursos, recurso.codigo, recurso)
    {:reply, {:ok, recurso}, %{estado | recursos: nuevo_mapa}}
  end

  @impl true
  def handle_call(:consultar_recursos, _from, estado) do
    {:reply, Map.values(estado.recursos), estado}
  end

  @impl true
  def handle_call({:asignar_recurso, codigo, cantidad}, _from, estado) do
    case Map.get(estado.recursos, codigo) do
      nil ->
        {:reply, {:error, "El recurso con código '#{codigo}' no existe"}, estado}

      %Recurso{cantidad: disponible} when disponible < cantidad ->
        {:reply, {:error, "Stock insuficiente. Disponible: #{disponible}, solicitado: #{cantidad}"}, estado}

      %Recurso{} = recurso ->
        recurso_actualizado = %{recurso | cantidad: recurso.cantidad - cantidad}
        nuevo_mapa = Map.put(estado.recursos, codigo, recurso_actualizado)
        {:reply, {:ok, recurso_actualizado}, %{estado | recursos: nuevo_mapa}}
    end
  end

  # --- Handlers de Albergues ---

  @impl true
  def handle_call({:registrar_albergue, %Albergue{} = albergue}, _from, estado) do
    nuevo_mapa = Map.put(estado.albergues, albergue.codigo, albergue)
    {:reply, {:ok, albergue}, %{estado | albergues: nuevo_mapa}}
  end

  @impl true
  def handle_call(:consultar_albergues, _from, estado) do
    {:reply, Map.values(estado.albergues), estado}
  end

  @impl true
  def handle_call({:ingresar_albergue, codigo, cantidad}, _from, estado) do
    case Map.get(estado.albergues, codigo) do
      nil ->
        {:reply, {:error, "El albergue con código '#{codigo}' no existe"}, estado}

      %Albergue{ocupacion_actual: ocupacion, capacidad_maxima: max} when ocupacion + cantidad > max ->
        disponible = max - ocupacion
        {:reply, {:error, "Capacidad excedida en albergue '#{codigo}'. Espacio disponible: #{disponible}"}, estado}

      %Albergue{} = albergue ->
        albergue_actualizado = %{albergue | ocupacion_actual: albergue.ocupacion_actual + cantidad}
        nuevo_mapa = Map.put(estado.albergues, codigo, albergue_actualizado)
        {:reply, {:ok, albergue_actualizado}, %{estado | albergues: nuevo_mapa}}
    end
  end

  # --- Handlers de Necesidades ---

  @impl true
  def handle_call({:registrar_necesidad, %Necesidad{} = necesidad}, _from, estado) do
    nuevo_mapa = Map.put(estado.necesidades, necesidad.id, necesidad)
    {:reply, {:ok, necesidad}, %{estado | necesidades: nuevo_mapa}}
  end

  @impl true
  def handle_call(:consultar_necesidades, _from, estado) do
    {:reply, Map.values(estado.necesidades), estado}
  end

  @impl true
  def handle_call({:cambiar_estado_necesidad, id, nuevo_estado, responsable}, _from, estado) do
    case Map.get(estado.necesidades, id) do
      nil ->
        {:reply, {:error, "La necesidad con ID '#{id}' no existe"}, estado}

      %Necesidad{} = necesidad ->
        necesidad_actualizada = %{necesidad | estado: nuevo_estado, responsable: responsable}
        nuevo_mapa = Map.put(estado.necesidades, id, necesidad_actualizada)
        {:reply, {:ok, necesidad_actualizada}, %{estado | necesidades: nuevo_mapa}}
    end
  end
end
