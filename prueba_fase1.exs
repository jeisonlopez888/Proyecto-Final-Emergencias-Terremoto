Code.require_file(Path.expand("estructuras.exs", __DIR__))

{:ok, u} = Usuario.nuevo("laura", "1234", "Laura Sánchez", :coordinador, "centro")
{:ok, z} = Zona.nueva("Z01", "Zona Centro", :critico, 450)
{:ok, n} = Necesidad.nueva("N001", "agua", 30, :critica, "Z01", "Agua para sector 3", "Laura")

IO.inspect(u, label: "Usuario")
IO.inspect(z, label: "Zona")
IO.inspect(n, label: "Necesidad")
