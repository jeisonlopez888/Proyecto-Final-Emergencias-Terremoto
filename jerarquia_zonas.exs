# =====================================================================
# UNIVERSIDAD DEL QUINDÍO - PROGRAMACIÓN III (PROYECTO FINAL)
# Autor: Jeison López
# =====================================================================

Code.require_file(Path.expand("estructuras.exs", __DIR__))

defmodule Emergencia.JerarquiaZonas do
  @moduledoc """
  Módulo de procesamiento recursivo sobre la estructura jerárquica:
  Zona -> Lista de Sectores -> Lista de Puntos de Atención.
  CUMPLE EL REQUISITO DE RECURSIVIDAD PROPIA DEL DOMINIO.
  """

  @doc """
  Cuenta el total de puntos de atención en una lista de sectores mediante recursión de cola.
  """
  def contar_puntos_sectores(sectores) do
    contar_puntos_rec(sectores, 0)
  end

  defp contar_puntos_rec([], acc), do: acc

  defp contar_puntos_rec([%Sector{puntos_atencion: puntos} | resto], acc) do
    num_puntos = largo_lista_rec(puntos, 0)
    contar_puntos_rec(resto, acc + num_puntos)
  end

  @doc """
  Consolida recursivamente todas las personas atendidas en los puntos de un sector.
  """
  def personas_atendidas_sector(%Sector{puntos_atencion: puntos}) do
    sumar_atendidos_rec(puntos, 0)
  end

  defp sumar_atendidos_rec([], acc), do: acc

  defp sumar_atendidos_rec([%PuntoAtencion{personas_atendidas: cant} | resto], acc) do
    sumar_atendidos_rec(resto, acc + cant)
  end

  # Auxiliar recursivo puro para contar elementos sin usar Enum.count
  defp largo_lista_rec([], acc), do: acc
  defp largo_lista_rec([_cabeza | cola], acc), do: largo_lista_rec(cola, acc + 1)
end
