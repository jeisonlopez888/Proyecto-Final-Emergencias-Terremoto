# =====================================================================
# UNIVERSIDAD DEL QUINDÍO - PROGRAMACIÓN III (PROYECTO FINAL)
# Autor: Jeison López
# =====================================================================


defmodule Emergencia.Supervisor do
  @moduledoc """
  Supervisor principal de la aplicación OTP.
  Estrategia :one_for_one -> Si el proceso ServidorRecursos falla (crash),
  el supervisor lo reinicia automáticamente en milisegundos sin tumbar la aplicación.
  """
  use Supervisor

  def start_link(opts \\ []) do
    Supervisor.start_link(__MODULE__, :ok, opts)
  end

  @impl true
  def init(:ok) do
    children = [
      {Emergencia.ServidorRecursos, [name: Emergencia.ServidorRecursos]}
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end
