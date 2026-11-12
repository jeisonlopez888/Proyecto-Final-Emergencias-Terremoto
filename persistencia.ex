# =====================================================================
# UNIVERSIDAD DEL QUINDÍO - PROGRAMACIÓN III (PROYECTO FINAL)
# Autor: Jeison López
# FASE 3: PERSISTENCIA Y AUDITORÍA EN ARCHIVOS PLANOS (.TXT)
# =====================================================================


defmodule Emergencia.Persistencia do
  @moduledoc """
  Módulo de persistencia perezosa con Stream para guardar y cargar:
  - zonas.txt
  - usuarios.txt
  - recursos.txt
  - albergues.txt
  - necesidades.txt
  - personas.txt
  - mensajes_familiares.txt
  - bitacora_transacciones.txt
  """

  # --- REGISTRO DE AUDITORÍA DE PETICIONES ---
  def registrar_auditoria(usuario_nombre, accion, detalles, ruta \\ "bitacora_transacciones.txt") do
    timestamp = DateTime.utc_now() |> DateTime.to_iso8601()

    linea =
      "[#{timestamp}] | Usuario: #{usuario_nombre} | Acción: #{accion} | Detalle: #{detalles}\n"

    [linea]
    |> Stream.into(File.stream!(ruta, [:append]))
    |> Stream.run()
  end

  # --- GUARDAR / CARGAR ZONAS ---
  def guardar_zonas(zonas, ruta \\ "zonas.txt") do
    lineas =
      zonas
      |> Stream.map(fn %{__struct__: Zona} = z ->
        "#{z.codigo};#{z.nombre};#{z.nivel_afectacion};#{z.personas_afectadas}\n"
      end)

    lineas
    |> Stream.into(File.stream!(ruta, [:write]))
    |> Stream.run()

    {:ok, Enum.count(zonas)}
  end

  def cargar_zonas(ruta \\ "zonas.txt") do
    if File.exists?(ruta) do
      zonas =
        File.stream!(ruta)
        |> Stream.map(&String.trim/1)
        |> Stream.filter(&(&1 != "" and not String.starts_with?(&1, "#")))
        |> Stream.map(fn linea ->
          case String.split(linea, ";") do
            [cod, nom, niv_str, pers_str] ->
              pers = String.to_integer(pers_str)

              case Zona.nueva(cod, nom, niv_str, pers) do
                {:ok, z} -> z
                _ -> nil
              end

            _ ->
              nil
          end
        end)
        |> Stream.reject(&is_nil/1)
        |> Enum.to_list()

      {:ok, zonas}
    else
      {:ok, []}
    end
  end

  # --- GUARDAR / CARGAR USUARIOS ---
  def guardar_usuarios(usuarios, ruta \\ "usuarios.txt") do
    lineas =
      usuarios
      |> Stream.map(fn %{__struct__: Usuario} = u ->
        "#{u.username};#{u.password};#{u.nombre};#{u.tipo};#{u.zona_principal};#{u.activo}\n"
      end)

    lineas
    |> Stream.into(File.stream!(ruta, [:write]))
    |> Stream.run()

    {:ok, Enum.count(usuarios)}
  end

  def cargar_usuarios(ruta \\ "usuarios.txt") do
    if File.exists?(ruta) do
      usuarios =
        File.stream!(ruta)
        |> Stream.map(&String.trim/1)
        |> Stream.filter(&(&1 != "" and not String.starts_with?(&1, "#")))
        |> Stream.map(fn linea ->
          case String.split(linea, ";") do
            [usr, pwd, nom, tipo_str, zona, act_str] ->
              activo = act_str == "true"

              case Usuario.nuevo(usr, pwd, nom, tipo_str, zona) do
                {:ok, u} -> %{u | activo: activo}
                _ -> nil
              end

            _ ->
              nil
          end
        end)
        |> Stream.reject(&is_nil/1)
        |> Enum.to_list()

      {:ok, usuarios}
    else
      {:ok, []}
    end
  end

  # --- GUARDAR / CARGAR RECURSOS ---
  def guardar_recursos(recursos, ruta \\ "recursos.txt") do
    lineas =
      recursos
      |> Stream.map(fn %{__struct__: Recurso} = r ->
        "#{r.codigo};#{r.nombre};#{r.categoria};#{r.cantidad};#{r.unidad};#{r.ubicacion};#{r.registrado_por};#{r.ultimo_modificador}\n"
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
            [cod, nom, cat, cant_str, uni, ubi, reg_por, mod_por] ->
              cant = String.to_integer(cant_str)
              {:ok, r} = Recurso.nuevo(cod, nom, cat, cant, uni, ubi, reg_por)
              %{r | ultimo_modificador: mod_por}

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
      |> Stream.map(fn %{__struct__: Albergue} = a ->
        "#{a.codigo};#{a.nombre};#{a.zona_codigo};#{a.capacidad_maxima};#{a.ocupacion_actual};#{a.registrado_por};#{a.ultimo_modificador}\n"
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
            [cod, nom, zona, cap_str, ocu_str, reg_por, mod_por] ->
              cap = String.to_integer(cap_str)
              ocu = String.to_integer(ocu_str)
              {:ok, a} = Albergue.nuevo(cod, nom, zona, cap, reg_por)
              %{a | ocupacion_actual: ocu, ultimo_modificador: mod_por}

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
      |> Stream.map(fn %{__struct__: Necesidad} = n ->
        "#{n.id};#{n.tipo};#{n.cantidad};#{n.prioridad};#{n.zona_codigo};#{n.solicitado_por};#{n.estado};#{n.responsable};#{n.descripcion}\n"
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
            [id, tipo, cant_str, prio_str, zona, sol_por, est_str, resp, desc] ->
              cant = String.to_integer(cant_str)
              prio = String.to_existing_atom(prio_str)
              est = String.to_existing_atom(est_str)
              {:ok, n} = Necesidad.nueva(id, tipo, cant, prio, zona, sol_por, desc, resp)
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

  # --- GUARDAR / CARGAR PERSONAS (REQUERIMIENTO 1.4.6) ---
  def guardar_personas(personas, ruta \\ "personas.txt") do
    lineas =
      personas
      |> Stream.map(fn %{__struct__: Persona} = p ->
        hist_str =
          p.historial_estados |> Enum.map(fn {est, ts} -> "#{est}@#{ts}" end) |> Enum.join("|")

        "#{p.documento};#{p.nombre};#{p.edad};#{p.zona_codigo};#{p.estado};#{hist_str}\n"
      end)

    lineas
    |> Stream.into(File.stream!(ruta, [:write]))
    |> Stream.run()

    {:ok, Enum.count(personas)}
  end

  def cargar_personas(ruta \\ "personas.txt") do
    if File.exists?(ruta) do
      personas =
        File.stream!(ruta)
        |> Stream.map(&String.trim/1)
        |> Stream.filter(&(&1 != "" and not String.starts_with?(&1, "#")))
        |> Stream.map(fn linea ->
          case String.split(linea, ";") do
            [doc, nom, edad_str, zona, est_str, hist_str] ->
              edad = String.to_integer(edad_str)
              est = String.to_atom(est_str)

              hist =
                if hist_str != "" do
                  hist_str
                  |> String.split("|")
                  |> Enum.map(fn e ->
                    case String.split(e, "@") do
                      [e_at, ts] -> {String.to_atom(e_at), ts}
                      _ -> {est, ""}
                    end
                  end)
                else
                  [{est, ""}]
                end

              {:ok, p} = Persona.nueva(doc, nom, zona, edad, est)
              %{p | historial_estados: hist}

            _ ->
              nil
          end
        end)
        |> Stream.reject(&is_nil/1)
        |> Enum.to_list()

      {:ok, personas}
    else
      {:ok, []}
    end
  end

  # --- GUARDAR / CARGAR MENSAJES FAMILIARES (REQUERIMIENTO 1.4.6) ---
  def guardar_mensajes(mensajes, ruta \\ "mensajes_familiares.txt") do
    lineas =
      mensajes
      |> Stream.map(fn %{__struct__: MensajeFamiliar} = m ->
        "#{m.id};#{m.remitente};#{m.destinatario_doc};#{m.estado};#{m.fecha};#{m.contenido}\n"
      end)

    lineas
    |> Stream.into(File.stream!(ruta, [:write]))
    |> Stream.run()

    {:ok, Enum.count(mensajes)}
  end

  def cargar_mensajes(ruta \\ "mensajes_familiares.txt") do
    if File.exists?(ruta) do
      mensajes =
        File.stream!(ruta)
        |> Stream.map(&String.trim/1)
        |> Stream.filter(&(&1 != "" and not String.starts_with?(&1, "#")))
        |> Stream.map(fn linea ->
          case String.split(linea, ";") do
            [id, rem, dest, est_str, fec, cont] ->
              est = String.to_existing_atom(est_str)
              {:ok, m} = MensajeFamiliar.nuevo(id, rem, dest, cont)
              %{m | estado: est, fecha: fec}

            _ ->
              nil
          end
        end)
        |> Stream.reject(&is_nil/1)
        |> Enum.to_list()

      {:ok, mensajes}
    else
      {:ok, []}
    end
  end
end
