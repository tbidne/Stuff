{
	"plugins": [
		"jasmine",
		"angular"
	],
	"extends": [
		"eslint:recommended",
		"plugin:angular/johnpapa",
		"plugin:jasmine/recommended"
	],
	"env": {
		"browser": true,
		"jasmine": true
	},
	"rules": {
		"angular/controller-as": 0,
		"angular/controller-as-vm": 0,
		"angular/function-type": 0,
		"angular/document-service": 0,
		"angular/window-service": 0,
		"jasmine/new-line-before-expect": 0,
		"no-unused-vars": 1
	},
	"globals": {
		"$": true,
		"angular": true,
		"GlobalServicesEndPoint": true,
		"inject": true,
		"module": true,
		"testUtils": true
	}
}