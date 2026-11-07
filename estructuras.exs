# =====================================================================
# UNIVERSIDAD DEL QUINDÍO - PROGRAMACIÓN III (PROYECTO FINAL)
# Autor: Jeison López
# FASE 1: STRUCTS Y MODELO DE DATOS DE LA EMERGENCIA (CON SEGURIDAD Y AUDITORÍA)
# =====================================================================

defmodule Usuario do
  @moduledoc """
  Representa un usuario autenticado en el sistema.
  Tipos permitidos: :ciudadano, :voluntario, :coordinador, :administrador
  """
  @enforce_keys [:username, :password, :nombre, :tipo]
  defstruct [:username, :password, :nombre, :tipo, :zona_principal, activo: true]

  @tipos_validos [:ciudadano, :voluntario, :coordinador, :administrador]

  def nuevo(username, password, nombre, tipo, zona_principal \\ "Sin zona") do
    tipo_atomo = if is_binary(tipo), do: String.to_existing_atom(tipo), else: tipo

    cond do
      username == "" or password == "" or nombre == "" ->
        {:error, "Campos obligatorios vacíos en usuario"}

      tipo_atomo not in @tipos_validos ->
        {:error, "Tipo de usuario inválido. Permitidos: #{@tipos_validos |> Enum.join(", ")}"}

      true ->
        {:ok, %__MODULE__{
          username: String.trim(username),
          password: String.trim(password),
          nombre: String.trim(nombre),
          tipo: tipo_atomo,
          zona_principal: zona_principal,
          activo: true
        }}
    end
  rescue
    ArgumentError -> {:error, "Tipo de usuario no reconocido"}
  end
end

defmodule Zona do
  @enforce_keys [:codigo, :nombre, :nivel_afectacion]
  defstruct [:codigo, :nombre, :nivel_afectacion, personas_afectadas: 0, sectores: []]

  @niveles [:critico, :alto, :medio, :bajo]

  def nueva(codigo, nombre, nivel, personas \\ 0) do
    nivel_at = if is_binary(nivel), do: String.to_existing_atom(nivel), else: nivel

    cond do
      codigo == "" or nombre == "" ->
        {:error, "Código o nombre de zona vacíos"}

      nivel_at not in @niveles ->
        {:error, "Nivel de afectación inválido"}

      personas < 0 ->
        {:error, "La cantidad de personas afectadas no puede ser negativa"}

      true ->
        {:ok, %__MODULE__{
          codigo: codigo,
          nombre: nombre,
          nivel_afectacion: nivel_at,
          personas_afectadas: personas,
          sectores: []
        }}
    end
  rescue
    ArgumentError -> {:error, "Nivel de afectación no reconocido"}
  end
end

defmodule Sector do
  @enforce_keys [:codigo, :nombre, :zona_codigo]
  defstruct [:codigo, :nombre, :zona_codigo, puntos_atencion: []]

  def nuevo(codigo, nombre, zona_codigo) do
    if codigo == "" or nombre == "" or zona_codigo == "" do
      {:error, "Datos incompletos para crear el sector"}
    else
      {:ok, %__MODULE__{codigo: codigo, nombre: nombre, zona_codigo: zona_codigo, puntos_atencion: []}}
    end
  end
end

defmodule PuntoAtencion do
  @enforce_keys [:codigo, :nombre, :sector_codigo]
  defstruct [:codigo, :nombre, :sector_codigo, personas_atendidas: 0]

  def nuevo(codigo, nombre, sector_codigo) do
    if codigo == "" or nombre == "" do
      {:error, "Código o nombre de punto de atención vacíos"}
    else
      {:ok, %__MODULE__{codigo: codigo, nombre: nombre, sector_codigo: sector_codigo, personas_atendidas: 0}}
    end
  end
end

defmodule Necesidad do
  @enforce_keys [:id, :tipo, :cantidad, :prioridad, :zona_codigo, :solicitado_por]
  defstruct [
    :id, :tipo, :cantidad, :prioridad, :zona_codigo, :solicitado_por,
    :descripcion, :responsable, estado: :pendiente
  ]

  @prioridades [:critica, :alta, :media, :baja]

  def nueva(id, tipo, cantidad, prioridad, zona_codigo, solicitado_por, descripcion \\ "", responsable \\ "") do
    prio_at = if is_binary(prioridad), do: String.to_existing_atom(prioridad), else: prioridad

    cond do
      id == "" or tipo == "" or zona_codigo == "" or solicitado_por == "" ->
        {:error, "Identificador, tipo, zona o usuario solicitante vacíos"}

      not is_number(cantidad) or cantidad <= 0 ->
        {:error, "La cantidad debe ser un número positivo"}

      prio_at not in @prioridades ->
        {:error, "Prioridad de necesidad inválida"}

      true ->
        {:ok, %__MODULE__{
          id: id,
          tipo: tipo,
          cantidad: cantidad,
          prioridad: prio_at,
          zona_codigo: zona_codigo,
          solicitado_por: solicitado_por,
          descripcion: descripcion,
          responsable: responsable,
          estado: :pendiente
        }}
    end
  rescue
    ArgumentError -> {:error, "Prioridad no reconocida"}
  end
end

defmodule Recurso do
  @enforce_keys [:codigo, :nombre, :categoria, :cantidad, :unidad, :ubicacion]
  defstruct [:codigo, :nombre, :categoria, :cantidad, :unidad, :ubicacion, registrado_por: "Sistema", ultimo_modificador: "Sistema"]

  def nuevo(codigo, nombre, categoria, cantidad, unidad, ubicacion, registrado_por \\ "Sistema") do
    cond do
      codigo == "" or nombre == "" or ubicacion == "" ->
        {:error, "Código, nombre o ubicación vacíos"}

      not is_number(cantidad) or cantidad < 0 ->
        {:error, "La cantidad del recurso no puede ser negativa"}

      true ->
        {:ok, %__MODULE__{
          codigo: codigo,
          nombre: nombre,
          categoria: categoria,
          cantidad: cantidad,
          unidad: unidad,
          ubicacion: ubicacion,
          registrado_por: registrado_por,
          ultimo_modificador: registrado_por
        }}
    end
  end
end

defmodule Persona do
  @enforce_keys [:documento, :nombre, :zona_codigo]
  defstruct [:documento, :nombre, :edad, :zona_codigo, estado: :reportada, historial_estados: []]

  @estados_validos [:sin_informacion, :reportada, :localizada, :trasladada, :en_albergue, :reunificada]

  def nueva(documento, nombre, zona_codigo, edad \\ 0, estado \\ :reportada) do
    est_at = if is_binary(estado), do: String.to_existing_atom(estado), else: estado

    cond do
      documento == "" or nombre == "" ->
        {:error, "Documento o nombre vacíos"}

      est_at not in @estados_validos ->
        {:error, "Estado de persona inválido"}

      true ->
        timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
        {:ok, %__MODULE__{
          documento: documento,
          nombre: nombre,
          zona_codigo: zona_codigo,
          edad: edad,
          estado: est_at,
          historial_estados: [{est_at, timestamp}]
        }}
    end
  rescue
    ArgumentError -> {:error, "Estado de persona no reconocido"}
  end
end

defmodule MensajeFamiliar do
  @enforce_keys [:id, :remitente, :destinatario_doc, :contenido]
  defstruct [:id, :remitente, :destinatario_doc, :contenido, :fecha, estado: :pendiente]

  def nuevo(id, remitente, destinatario_doc, contenido) do
    if id == "" or remitente == "" or destinatario_doc == "" or contenido == "" do
      {:error, "Campos obligatorios de mensaje vacíos"}
    else
      {:ok, %__MODULE__{
        id: id,
        remitente: remitente,
        destinatario_doc: destinatario_doc,
        contenido: contenido,
        fecha: DateTime.utc_now() |> DateTime.to_iso8601(),
        estado: :pendiente
      }}
    end
  end
end

defmodule Mascota do
  @enforce_keys [:id, :tipo_reporte, :especie, :caracteristicas, :zona_codigo, :contacto, :registrado_por]
  defstruct [
    :id, :tipo_reporte, :especie, :nombre, :caracteristicas,
    :color, :tamano, :zona_codigo, :contacto, :registrado_por, estado: :activa
  ]

  def nueva(id, tipo_reporte, especie, nombre, caracteristicas, color, tamano, zona_codigo, contacto, registrado_por \\ "Sistema") do
    tipo_at = if is_binary(tipo_reporte), do: String.to_existing_atom(tipo_reporte), else: tipo_reporte

    cond do
      id == "" or contacto == "" or zona_codigo == "" ->
        {:error, "ID, contacto o zona de mascota vacíos"}

      tipo_at not in [:perdida, :encontrada] ->
        {:error, "Tipo de reporte debe ser :perdida o :encontrada"}

      true ->
        {:ok, %__MODULE__{
          id: id,
          tipo_reporte: tipo_at,
          especie: String.downcase(especie),
          nombre: nombre,
          caracteristicas: String.downcase(caracteristicas),
          color: String.downcase(color),
          tamano: String.downcase(tamano),
          zona_codigo: zona_codigo,
          contacto: contacto,
          registrado_por: registrado_por,
          estado: :activa
        }}
    end
  rescue
    ArgumentError -> {:error, "Tipo de reporte no reconocido"}
  end
end

defmodule Albergue do
  @enforce_keys [:codigo, :nombre, :zona_codigo, :capacidad_maxima]
  defstruct [:codigo, :nombre, :zona_codigo, :capacidad_maxima, ocupacion_actual: 0, registrado_por: "Sistema", ultimo_modificador: "Sistema"]

  def nuevo(codigo, nombre, zona_codigo, capacidad_maxima, registrado_por \\ "Sistema") do
    cond do
      codigo == "" or nombre == "" ->
        {:error, "Código o nombre de albergue vacíos"}

      not is_integer(capacidad_maxima) or capacidad_maxima <= 0 ->
        {:error, "La capacidad máxima del albergue debe ser un entero positivo"}

      true ->
        {:ok, %__MODULE__{
          codigo: codigo,
          nombre: nombre,
          zona_codigo: zona_codigo,
          capacidad_maxima: capacidad_maxima,
          ocupacion_actual: 0,
          registrado_por: registrado_por,
          ultimo_modificador: registrado_por
        }}
    end
  end
end
