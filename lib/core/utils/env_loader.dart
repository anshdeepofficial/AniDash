// ignore_for_file: constant_identifier_names

const API_URL = String.fromEnvironment('API_URL');
const COMMENTUM_API_URL = String.fromEnvironment('COMMENTUM_API_URL');

const ANILIST_CLIENT_ID = String.fromEnvironment(
  'ANILIST_CLIENT_ID',
  defaultValue: '50037|50037',
);
const ANILIST_CLIENT_SECRET = String.fromEnvironment(
  'ANILIST_CLIENT_SECRET',
  defaultValue:
      'inpCGvXD5r2UglDrE6UHslYdSbW8GNBCBbgddDzW|inpCGvXD5r2UglDrE6UHslYdSbW8GNBCBbgddDzW',
);

const MAL_CLIENT_ID = String.fromEnvironment('MAL_CLIENT_ID');
const MAL_CLIENT_SECRET = String.fromEnvironment('MAL_CLIENT_SECRET');
