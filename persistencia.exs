# =====================================================================
# UNIVERSIDAD DEL QUINDÍO - PROGRAMACIÓN III (PROYECTO FINAL)
# Autor: Jeison López
# FASE 3: MÓDULO DE PERSISTENCIA EN ARCHIVOS PLANOS (EVALUACIÓN PEREZOSA)
# =====================================================================

Code.require_file(Path.expand("estructuras.exs", __DIR__))

defmodule Emergencia.Persistencia do
  @moduledoc """
  Módulo encargado de guardar y cargar el estado del sistema en archivos planos.
  Utiliza evaluación perezosa (Stream) para evitar sobrecargar la memoria RAM.
  Archivos soportados:
  - recursos.txt
  - albergues.txt
  - necesidades.txt
  """

  # --- GUARDAR / CARGAR RECURSOS ---

  def guardar_recursos(recursos, ruta \\ "recursos.txt") do
    lineas =
      recursos
      |> Stream.map(fn %Recurso{} = r ->
        "#{r.codigo};#{r.nombre};#{r.categoria};#{r.cantidad};#{r.unidad};#{r.ubicacion}\n"
      end)

    lineas
    |> Stream.into(File.stream!(ruta, [:write]))
    |> Stream.run()

    {:ok, Enum.count(recursos)}
  end

  def cargar_recursos(ruta \\ "recursos.txt") do
    if File.exists?(ruta) do
      recursos =
        File.stream!(ruta)
        |> Stream.map(&String.trim/1)
        |> Stream.filter(&(&1 != "" and not String.starts_with?(&1, "#")))
        |> Stream.map(fn linea ->
          case String.split(linea, ";") do
            [cod, nom, cat, cant_str, uni, ubi] ->
              cant = String.to_integer(cant_str)
              {:ok, r} = Recurso.nuevo(cod, nom, cat, cant, uni, ubi)
              r

            _ ->
              nil
          end
        end)
        |> Stream.reject(&is_nil/1)
        |> Enum.to_list()

      {:ok, recursos}
    else
      {:ok, []}
    end
  end

  # --- GUARDAR / CARGAR ALBERGUES ---

  def guardar_albergues(albergues, ruta \\ "albergues.txt") do
    lineas =
      albergues
      |> Stream.map(fn %Albergue{} = a ->
        "#{a.codigo};#{a.nombre};#{a.zona_codigo};#{a.capacidad_maxima};#{a.ocupacion_actual}\n"
      end)

    lineas
    |> Stream.into(File.stream!(ruta, [:write]))
    |> Stream.run()

    {:ok, Enum.count(albergues)}
  end

  def cargar_albergues(ruta \\ "albergues.txt") do
    if File.exists?(ruta) do
      albergues =
        File.stream!(ruta)
        |> Stream.map(&String.trim/1)
        |> Stream.filter(&(&1 != "" and not String.starts_with?(&1, "#")))
        |> Stream.map(fn linea ->
          case String.split(linea, ";") do
            [cod, nom, zona, cap_str, ocu_str] ->
              cap = String.to_integer(cap_str)
              ocu = String.to_integer(ocu_str)
              {:ok, a} = Albergue.nuevo(cod, nom, zona, cap)
              %{a | ocupacion_actual: ocu}

            _ ->
              nil
          end
        end)
        |> Stream.reject(&is_nil/1)
        |> Enum.to_list()

      {:ok, albergues}
    else
      {:ok, []}
    end
  end

  # --- GUARDAR / CARGAR NECESIDADES ---

  def guardar_necesidades(necesidades, ruta \\ "necesidades.txt") do
    lineas =
      necesidades
      |> Stream.map(fn %Necesidad{} = n ->
        "#{n.id};#{n.tipo};#{n.cantidad};#{n.prioridad};#{n.zona_codigo};#{n.estado};#{n.responsable};#{n.descripcion}\n"
      end)

    lineas
    |> Stream.into(File.stream!(ruta, [:write]))
    |> Stream.run()

    {:ok, Enum.count(necesidades)}
  end

  def cargar_necesidades(ruta \\ "necesidades.txt") do
    if File.exists?(ruta) do
      necesidades =
        File.stream!(ruta)
        |> Stream.map(&String.trim/1)
        |> Stream.filter(&(&1 != "" and not String.starts_with?(&1, "#")))
        |> Stream.map(fn linea ->
          case String.split(linea, ";") do
            [id, tipo, cant_str, prio_str, zona, est_str, resp, desc] ->
              cant = String.to_integer(cant_str)
              prio = String.to_existing_atom(prio_str)
              est = String.to_existing_atom(est_str)
              {:ok, n} = Necesidad.nueva(id, tipo, cant, prio, zona, desc, resp)
              %{n | estado: est}

            _ ->
              nil
          end
        end)
        |> Stream.reject(&is_nil/1)
        |> Enum.to_list()

      {:ok, necesidades}
    else
      {:ok, []}
    end
  end
end
