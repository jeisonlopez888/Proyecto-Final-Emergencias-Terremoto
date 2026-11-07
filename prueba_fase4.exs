Code.require_file(Path.expand("estructuras.exs", __DIR__))
Code.require_file(Path.expand("jerarquia_zonas.exs", __DIR__))
Code.require_file(Path.expand("personas_mascotas.exs", __DIR__))

# 1. Probar Jerarquía y Recursividad en Zonas
{:ok, p1} = PuntoAtencion.nuevo("P01", "Punto Medico 1", "S01")
{:ok, p2} = PuntoAtencion.nuevo("P02", "Punto Hidratacion", "S01")
p1_at = %{p1 | personas_atendidas: 25}
p2_at = %{p2 | personas_atendidas: 40}

{:ok, s1} = Sector.nuevo("S01", "Sector Norte", "Z01")
s1_completo = %{s1 | puntos_atencion: [p1_at, p2_at]}

puntos_totales = Emergencia.JerarquiaZonas.contar_puntos_sectores([s1_completo])
personas_atendidas = Emergencia.JerarquiaZonas.personas_atendidas_sector(s1_completo)

IO.puts("--- PRUEBA DE RECURSIVIDAD EN JERARQUÍA ---")
IO.puts("Total puntos de atención en sectores: #{puntos_totales}")
IO.puts("Total personas atendidas en sector S01: #{personas_atendidas}")

# 2. Probar Algoritmo de Matching de Mascotas
{:ok, m_perdida} =
  Mascota.nueva(
    "M01",
    :perdida,
    "Perro",
    "Lucas",
    "Pastor aleman con collar rojo",
    "negro",
    "grande",
    "Z01",
    "3001234567"
  )

{:ok, m_enc1} =
  Mascota.nueva(
    "M02",
    :encontrada,
    "Perro",
    "Sin nombre",
    "Encontrado en parque",
    "negro",
    "grande",
    "Z01",
    "3119876543"
  )

{:ok, m_enc2} =
  Mascota.nueva(
    "M03",
    :encontrada,
    "Gato",
    "Sin nombre",
    "Gato blanco pequeño",
    "blanco",
    "pequeno",
    "Z02",
    "3120001122"
  )

coincidencias = Emergencia.MatchingMascotas.encontrar_coincidencias(m_perdida, [m_enc1, m_enc2])

IO.puts("\n--- PRUEBA DE MATCHING DE MASCOTAS ---")

Enum.each(coincidencias, fn {mascota, score} ->
  IO.puts(
    "Coincidencia detectada: ID #{mascota.id} (#{mascota.especie}, #{mascota.color}) -> Coincidencia: #{score}%"
  )
end)
