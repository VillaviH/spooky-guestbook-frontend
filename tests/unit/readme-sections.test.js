'use strict';

/**
 * Prueba unitaria que verifica que el README de Frontend_Repository
 * contiene las secciones obligatorias.
 *
 * Feature: aws-serverless-hackathon-demo
 * Tarea 24.2: Escribir una prueba unitaria que verifique que el README
 * contiene las secciones obligatorias.
 *
 * Validates: Requirements 11.2
 */

const fs = require('fs');
const path = require('path');

const readmePath = path.join(__dirname, '..', '..', 'README.md');
const readmeContent = fs.readFileSync(readmePath, 'utf8');

describe('README.md - secciones obligatorias (Requirements 11.2)', () => {
  it('contiene una seccion de arquitectura', () => {
    expect(readmeContent).toMatch(/^#+\s*Arquitectura/mi);
  });

  it('contiene una seccion de despliegue con una lista numerada de al menos 3 pasos', () => {
    expect(readmeContent).toMatch(/^#+\s*Despliegue/mi);

    const numberedLines = readmeContent.match(/^\s*\d+\.\s+\S/gm) || [];
    expect(numberedLines.length).toBeGreaterThanOrEqual(3);
  });

  it('contiene las instrucciones para configurar el endpoint de Backend_API', () => {
    expect(readmeContent).toMatch(/Backend_API/i);
    expect(readmeContent).toMatch(/endpoint|config/i);
  });

  it('menciona los componentes de arquitectura por nombre', () => {
    expect(readmeContent).toMatch(/S3[_ ]Bucket/i);
    expect(readmeContent).toMatch(/CloudFront[_ ]Distribution|CloudFront\b/i);
  });
});
