import { describe, it, expect } from 'vitest';
import { deriveHiddenPathsFromYaml } from './hidden-paths';

describe('deriveHiddenPathsFromYaml', () => {
  it('returns empty array for non-hidden YAML', () => {
    const yaml = 'path: tennis\ntitle: Tennis';
    expect(deriveHiddenPathsFromYaml(yaml)).toEqual([]);
  });

  it('returns empty array when hidden but no path field', () => {
    const yaml = 'hidden: true\ntitle: Secret';
    expect(deriveHiddenPathsFromYaml(yaml)).toEqual([]);
  });

  it('returns both slash forms for a simple already-slugified path', () => {
    const yaml = 'path: tennis/atx-open-2025\nhidden: true';
    expect(deriveHiddenPathsFromYaml(yaml)).toEqual([
      '/tennis/atx-open-2025',
      '/tennis/atx-open-2025/',
    ]);
  });

  it('slugifies path segments that contain capitals or underscores', () => {
    const yaml = 'path: Tennis/ATX_Open_2025\nhidden: true';
    expect(deriveHiddenPathsFromYaml(yaml)).toEqual([
      '/tennis/atx-open-2025',
      '/tennis/atx-open-2025/',
    ]);
  });

  it('applies slug override to the final segment', () => {
    const yaml = 'path: tennis/atx-open-2025\nslug: atx-25\nhidden: true';
    expect(deriveHiddenPathsFromYaml(yaml)).toEqual([
      '/tennis/atx-25',
      '/tennis/atx-25/',
    ]);
  });

  it('slugifies the slug override value', () => {
    const yaml = 'path: tennis/atx-open-2025\nslug: ATX 25\nhidden: true';
    expect(deriveHiddenPathsFromYaml(yaml)).toEqual([
      '/tennis/atx-25',
      '/tennis/atx-25/',
    ]);
  });

  it('strips leading and trailing slashes from path', () => {
    const yaml = 'path: /tennis/hidden-set/\nhidden: true';
    expect(deriveHiddenPathsFromYaml(yaml)).toEqual([
      '/tennis/hidden-set',
      '/tennis/hidden-set/',
    ]);
  });

  it('handles a top-level hidden node', () => {
    const yaml = 'path: secret\nhidden: true';
    expect(deriveHiddenPathsFromYaml(yaml)).toEqual(['/secret', '/secret/']);
  });
});
