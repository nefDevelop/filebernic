# Configuración de Pruebas

Este documento explica cómo configurar el entorno de pruebas para este proyecto.

## 1. Instalar `luarocks`

`luarocks` es el gestor de paquetes para Lua. Lo necesitarás para instalar `busted`, nuestro framework de pruebas.

Abre Termux y ejecuta el siguiente comando:

```bash
pkg install luarocks
```

Si obtienes errores de red, puede que necesites cambiar tu repositorio. Puedes hacerlo ejecutando:

```bash
termux-change-repo
```
y seleccionando un espejo (mirror) diferente. Después de eso, intenta instalar `luarocks` de nuevo.

## 2. Instalar `busted`

Una vez que `luarocks` esté instalado, puedes instalar `busted`:

```bash
luarocks install busted
```

## 3. Ejecutar las pruebas

Para ejecutar las pruebas, usa el comando `busted` en el directorio raíz del proyecto:

```bash
busted
```
