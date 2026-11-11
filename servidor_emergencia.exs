# =====================================================================
# UNIVERSIDAD DEL QUINDÍO - PROGRAMACIÓN III (PROYECTO FINAL)
# Autor: Jeison López
# FASE 2: SERVIDOR CONCURRENTE CON GENSERVER
# =====================================================================

Code.require_file(Path.expand("estructuras.exs", __DIR__))
Code.require_file(Path.expand("persistencia.exs", __DIR__))

defmodule Emergencia.ServidorRecursos do
  @moduledoc """
  GenServer centralizado para la gestión concurrente y atómica de:
  1. Zonas Geográficas.
  2. Autenticación y Usuarios.
  3. Recursos e Inventarios.
  4. Albergues.
  5. Necesidades.
  6. Censo de Personas Afectadas (1.4.6).
  7. Mensajería Familiar (1.4.6).
  """
  use GenServer

  # -------------------------------------------------------------------
  # CLIENT API
  # -------------------------------------------------------------------

  def start_link(opts \\ []) do
    nombre = Keyword.get(opts, :name, __MODULE__)
    GenServer.start_link(__MODULE__, :ok, name: nombre)
  end

  # --- ZONAS ---
  def registrar_zona(zona), do: GenServer.call(__MODULE__, {:registrar_zona, zona})
  def consultar_zonas, do: GenServer.call(__MODULE__, :consultar_zonas)

  # --- USUARIOS ---
  def registrar_usuario(usuario), do: GenServer.call(__MODULE__, {:registrar_usuario, usuario})

  def autenticar_usuario(username, password),
    do: GenServer.call(__MODULE__, {:autenticar_usuario, username, password})

  def consultar_usuarios, do: GenServer.call(__MODULE__, :consultar_usuarios)

  # --- RECURSOS ---
  def registrar_recurso(recurso, usuario_nombre \\ "Sistema") do
    GenServer.call(__MODULE__, {:registrar_recurso, recurso, usuario_nombre})
  end

  def consultar_recursos, do: GenServer.call(__MODULE__, :consultar_recursos)

  def asignar_recurso(codigo, cantidad, usuario_nombre) do
    GenServer.call(__MODULE__, {:asignar_recurso, codigo, cantidad, usuario_nombre})
  end

  # --- ALBERGUES ---
  def registrar_albergue(albergue, usuario_nombre \\ "Sistema") do
    GenServer.call(__MODULE__, {:registrar_albergue, albergue, usuario_nombre})
  end

  def consultar_albergues, do: GenServer.call(__MODULE__, :consultar_albergues)

  def ingresar_albergue(codigo, cantidad, usuario_nombre) do
    GenServer.call(__MODULE__, {:ingresar_albergue, codigo, cantidad, usuario_nombre})
  end

  # --- NECESIDADES ---
  def registrar_necesidad(necesidad),
    do: GenServer.call(__MODULE__, {:registrar_necesidad, necesidad})

  def consultar_necesidades, do: GenServer.call(__MODULE__, :consultar_necesidades)

  # --- PERSONAS AFECTADAS (1.4.6) ---
  def registrar_persona(persona), do: GenServer.call(__MODULE__, {:registrar_persona, persona})
  def consultar_personas, do: GenServer.call(__MODULE__, :consultar_personas)

  def buscar_personas(criterio, valor),
    do: GenServer.call(__MODULE__, {:buscar_personas, criterio, valor})

  def cambiar_estado_persona(documento, nuevo_estado) do
    GenServer.call(__MODULE__, {:cambiar_estado_persona, documento, nuevo_estado})
  end

  # --- MENSAJES FAMILIARES (1.4.6) ---
  def registrar_mensaje(mensaje), do: GenServer.call(__MODULE__, {:registrar_mensaje, mensaje})
  def consultar_mensajes, do: GenServer.call(__MODULE__, :consultar_mensajes)

  def consultar_mensajes_destinatario(destinatario_doc) do
    GenServer.call(__MODULE__, {:consultar_mensajes_destinatario, destinatario_doc})
  end

  def cambiar_estado_mensaje(id_mensaje, nuevo_estado) do
    GenServer.call(__MODULE__, {:cambiar_estado_mensaje, id_mensaje, nuevo_estado})
  end

  # -------------------------------------------------------------------
  # SERVER CALLBACKS
  # -------------------------------------------------------------------

  @impl true
  def init(:ok) do
    {:ok,
     %{
       zonas: %{},
       usuarios: %{},
       recursos: %{},
       albergues: %{},
       necesidades: %{},
       personas: %{},
       mensajes: %{}
     }}
  end

  @impl true
  def handle_call({:registrar_zona, %{__struct__: Zona} = z}, _from, estado) do
    {:reply, {:ok, z}, %{estado | zonas: Map.put(estado.zonas, z.codigo, z)}}
  end

  @impl true
  def handle_call(:consultar_zonas, _from, estado), do: {:reply, Map.values(estado.zonas), estado}

  @impl true
  def handle_call({:registrar_usuario, %{__struct__: Usuario} = u}, _from, estado) do
    case Map.get(estado.usuarios, u.username) do
      nil -> {:reply, {:ok, u}, %{estado | usuarios: Map.put(estado.usuarios, u.username, u)}}
      _ -> {:reply, {:error, "Usuario ya existe"}, estado}
    end
  end

  @impl true
  def handle_call({:autenticar_usuario, username, password}, _from, estado) do
    case Map.get(estado.usuarios, username) do
      %{__struct__: Usuario, password: ^password} = u -> {:reply, {:ok, u}, estado}
      _ -> {:reply, {:error, "Credenciales inválidas"}, estado}
    end
  end

  @impl true
  def handle_call(:consultar_usuarios, _from, estado),
    do: {:reply, Map.values(estado.usuarios), estado}

  @impl true
  def handle_call({:registrar_recurso, %{__struct__: Recurso} = r, u_nom}, _from, estado) do
    r_aut = %{r | registrado_por: u_nom, ultimo_modificador: u_nom}
    {:reply, {:ok, r_aut}, %{estado | recursos: Map.put(estado.recursos, r.codigo, r_aut)}}
  end

  @impl true
  def handle_call(:consultar_recursos, _from, estado),
    do: {:reply, Map.values(estado.recursos), estado}

  @impl true
  def handle_call({:asignar_recurso, cod, cant, u_nom}, _from, estado) do
    case Map.get(estado.recursos, cod) do
      nil ->
        {:reply, {:error, "Recurso inexistente"}, estado}

      %{__struct__: Recurso, cantidad: disp} when disp < cant ->
        {:reply, {:error, "Stock insuficiente"}, estado}

      %{__struct__: Recurso} = r ->
        r_act = %{r | cantidad: r.cantidad - cant, ultimo_modificador: u_nom}
        {:reply, {:ok, r_act}, %{estado | recursos: Map.put(estado.recursos, cod, r_act)}}
    end
  end

  @impl true
  def handle_call({:registrar_albergue, %{__struct__: Albergue} = a, u_nom}, _from, estado) do
    a_aut = %{a | registrado_por: u_nom, ultimo_modificador: u_nom}
    {:reply, {:ok, a_aut}, %{estado | albergues: Map.put(estado.albergues, a.codigo, a_aut)}}
  end

  @impl true
  def handle_call(:consultar_albergues, _from, estado),
    do: {:reply, Map.values(estado.albergues), estado}

  @impl true
  def handle_call({:ingresar_albergue, cod, cant, u_nom}, _from, estado) do
    case Map.get(estado.albergues, cod) do
      nil ->
        {:reply, {:error, "Albergue inexistente"}, estado}

      %{__struct__: Albergue, ocupacion_actual: ocu, capacidad_maxima: max} when ocu + cant > max ->
        {:reply, {:error, "Capacidad excedida"}, estado}

      %{__struct__: Albergue} = a ->
        a_act = %{a | ocupacion_actual: a.ocupacion_actual + cant, ultimo_modificador: u_nom}
        {:reply, {:ok, a_act}, %{estado | albergues: Map.put(estado.albergues, cod, a_act)}}
    end
  end

  @impl true
  def handle_call({:registrar_necesidad, %{__struct__: Necesidad} = n}, _from, estado) do
    {:reply, {:ok, n}, %{estado | necesidades: Map.put(estado.necesidades, n.id, n)}}
  end

  @impl true
  def handle_call(:consultar_necesidades, _from, estado),
    do: {:reply, Map.values(estado.necesidades), estado}

  # --- HANDLERS PERSONAS ---
  @impl true
  def handle_call({:registrar_persona, %{__struct__: Persona} = p}, _from, estado) do
    {:reply, {:ok, p}, %{estado | personas: Map.put(estado.personas, p.documento, p)}}
  end

  @impl true
  def handle_call(:consultar_personas, _from, estado),
    do: {:reply, Map.values(estado.personas), estado}

  @impl true
  def handle_call({:buscar_personas, criterio, valor}, _from, estado) do
    val_lower = String.downcase(to_string(valor))

    coincidencias =
      estado.personas
      |> Map.values()
      |> Enum.filter(fn p ->
        case criterio do
          :documento -> String.contains?(String.downcase(p.documento), val_lower)
          :nombre -> String.contains?(String.downcase(p.nombre), val_lower)
          :zona -> String.contains?(String.downcase(p.zona_codigo), val_lower)
          :estado -> to_string(p.estado) == val_lower
          _ -> false
        end
      end)

    {:reply, coincidencias, estado}
  end

  @impl true
  def handle_call({:cambiar_estado_persona, doc, nuevo_est}, _from, estado) do
    case Map.get(estado.personas, doc) do
      nil ->
        {:reply, {:error, "Persona con documento '#{doc}' no encontrada"}, estado}

      %{__struct__: Persona} = p ->
        ts = DateTime.utc_now() |> DateTime.to_iso8601()

        p_act = %{
          p
          | estado: nuevo_est,
            historial_estados: [{nuevo_est, ts} | p.historial_estados]
        }

        {:reply, {:ok, p_act}, %{estado | personas: Map.put(estado.personas, doc, p_act)}}
    end
  end

  # --- HANDLERS MENSAJES ---
  @impl true
  def handle_call({:registrar_mensaje, %{__struct__: MensajeFamiliar} = m}, _from, estado) do
    {:reply, {:ok, m}, %{estado | mensajes: Map.put(estado.mensajes, m.id, m)}}
  end

  @impl true
  def handle_call(:consultar_mensajes, _from, estado),
    do: {:reply, Map.values(estado.mensajes), estado}

  @impl true
  def handle_call({:consultar_mensajes_destinatario, doc}, _from, estado) do
    res = estado.mensajes |> Map.values() |> Enum.filter(&(&1.destinatario_doc == doc))
    {:reply, res, estado}
  end

  @impl true
  def handle_call({:cambiar_estado_mensaje, id, nuevo_est}, _from, estado) do
    case Map.get(estado.mensajes, id) do
      nil ->
        {:reply, {:error, "Mensaje inexistente"}, estado}

      %{__struct__: MensajeFamiliar} = m ->
        m_act = %{m | estado: nuevo_est}
        {:reply, {:ok, m_act}, %{estado | mensajes: Map.put(estado.mensajes, id, m_act)}}
    end
  end
end
