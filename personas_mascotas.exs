# =====================================================================
# UNIVERSIDAD DEL QUINDÍO - PROGRAMACIÓN III (PROYECTO FINAL)
# Autor: Jeison López
# FASE 4: PERSONAS, MENSAJERÍA Y ALGORITMO DE MATCHING DE MASCOTAS
# =====================================================================

Code.require_file(Path.expand("estructuras.exs", __DIR__))

defmodule Emergencia.GestionPersonas do
  @moduledoc """
  Gestión de personas afectadas e historial de estados.
  """

  def actualizar_estado(%Persona{} = persona, nuevo_estado) do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()
    nuevo_historial = [{nuevo_estado, timestamp} | persona.historial_estados]
    %{persona | estado: nuevo_estado, historial_estados: nuevo_historial}
  end
end

defmodule Emergencia.MatchingMascotas do
  @moduledoc """
  Algoritmo de puntuación para emparejar mascotas perdidas y encontradas.
  Puntuación máxima: 100 puntos.
  - Misma especie: +40 pts
  - Misma zona: +30 pts
  - Mismo color: +15 pts
  - Mismo tamaño: +15 pts
  """

  def encontrar_coincidencias(
        %Mascota{tipo_reporte: :perdida} = perdida,
        lista_mascotas,
        umbral \\ 50
      ) do
    lista_mascotas
    |> Stream.filter(fn m -> m.tipo_reporte == :encontrada and m.estado == :activa end)
    |> Stream.map(fn encontrada ->
      score = calcular_puntuacion(perdida, encontrada)
      {encontrada, score}
    end)
    |> Stream.filter(fn {_m, score} -> score >= umbral end)
    |> Enum.sort_by(fn {_m, score} -> score end, :desc)
  end

  defp calcular_puntuacion(m1, m2) do
    pts_especie = if m1.especie == m2.especie, do: 40, else: 0
    pts_zona = if m1.zona_codigo == m2.zona_codigo, do: 30, else: 0
    pts_color = if m1.color == m2.color, do: 15, else: 0
    pts_tam = if m1.tamano == m2.tamano, do: 15, else: 0

    pts_especie + pts_zona + pts_color + pts_tam
  end
end
