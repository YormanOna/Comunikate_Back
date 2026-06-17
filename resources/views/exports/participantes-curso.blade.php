<!DOCTYPE html>
<html>
<head>
<meta charset="utf-8">
<title>Participantes - {{ $curso->nombre_instancia }}</title>
<style>
    body { font-family: sans-serif; font-size: 11px; color: #333; }
    h1 { font-size: 16px; margin-bottom: 5px; }
    h2 { font-size: 13px; font-weight: normal; color: #666; margin-top: 0; margin-bottom: 15px; }
    table { width: 100%; border-collapse: collapse; }
    th { background: #f3f4f6; text-align: left; padding: 8px 6px; font-size: 10px; text-transform: uppercase; letter-spacing: 0.05em; border-bottom: 2px solid #e5e7eb; }
    td { padding: 7px 6px; border-bottom: 1px solid #e5e7eb; }
    .total { margin-top: 15px; font-size: 11px; color: #666; }
</style>
</head>
<body>
    <h1>{{ $curso->nombre_instancia }}</h1>
    <h2>Listado de Participantes</h2>
    <table>
        <thead>
            <tr>
                <th>Nombres</th>
                <th>Apellidos</th>
                <th>Cédula</th>
                <th>Correo</th>
                <th>Fecha Inscripción</th>
            </tr>
        </thead>
        <tbody>
            @foreach($rows as $r)
            <tr>
                <td>{{ $r['nombres'] }}</td>
                <td>{{ $r['apellidos'] }}</td>
                <td>{{ $r['cedula'] }}</td>
                <td>{{ $r['correo'] }}</td>
                <td>{{ $r['fecha'] }}</td>
            </tr>
            @endforeach
        </tbody>
    </table>
    <p class="total">Total: {{ count($rows) }} estudiante{{ count($rows) !== 1 ? 's' : '' }}</p>
</body>
</html>
