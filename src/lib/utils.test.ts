import { describe, it, expect } from 'vitest';
import { toSlug, toTitle } from './utils';

// Smoke tests — verifies the Vitest harness runs and the pure utils are sane.
describe('toSlug', () => {
  it('lowercases and replaces spaces with hyphens', () => {
    expect(toSlug('My Album')).toBe('my-album');
  });

  it('converts underscores to hyphens', () => {
    expect(toSlug('atx_open_2025')).toBe('atx-open-2025');
  });

  it('strips non-alphanumeric characters', () => {
    expect(toSlug('Tennis (Open)')).toBe('tennis-open');
  });

  it('trims leading and trailing hyphens', () => {
    expect(toSlug('  hello  ')).toBe('hello');
  });
});

describe('toTitle', () => {
  it('converts hyphens to spaces and capitalizes', () => {
    expect(toTitle('atx-open-2025')).toBe('Atx Open 2025');
  });

  it('converts underscores to spaces and capitalizes', () => {
    expect(toTitle('my_photos')).toBe('My Photos');
  });
});
