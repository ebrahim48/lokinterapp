import 'package:get/get.dart';

// App-owned UI copy in English and French. Server messages and CMS content are
// localized by the API (via the X-Lang header) and are not repeated here.
// Add keys as more screens are localized; missing keys fall back to English.
class AppTranslations extends Translations {
  @override
  Map<String, Map<String, String>> get keys => {
        'en': _en,
        'fr': _fr,
      };
}

const _en = <String, String>{
  // bottom navigation
  'nav.home': 'Home',
  'nav.deals': 'Deals',
  'nav.chat': 'Chat',
  'nav.profile': 'Profile',
  // welcome
  'welcome.tagline': 'Ship anything, anywhere',
  'welcome.subtitle':
      'Connect with travelers heading your way and send parcels locally or across the world.',
  'welcome.login': 'Login',
  'welcome.createAccount': 'Create an account',
  'welcome.guest': 'Continue as guest',
  // auth
  'auth.welcomeBack': 'Welcome back',
  'auth.loginSubtitle': 'Log in to keep shipping and traveling.',
  'auth.email': 'Email',
  'auth.password': 'Password',
  'auth.forgotPassword': 'Forgot password?',
  'auth.noAccount': "Don't have an account? ",
  'auth.signUp': 'Sign up',
  'auth.haveAccount': 'Already have an account? ',
  'auth.signIn': 'Sign in',
  'auth.createAccount': 'Create account',
  // common actions
  'common.save': 'Save',
  'common.cancel': 'Cancel',
  'common.retry': 'Retry',
  'common.close': 'Close',
  'common.continue': 'Continue',
  'common.confirm': 'Confirm',
  'common.delete': 'Delete',
  'common.edit': 'Edit',
  'common.search': 'Search',
  'common.language': 'Language',
  // deals
  'deals.title': 'Deals',
  'deals.filter': 'Filter deals',
  'deals.all': 'All',
  'deals.empty': 'No deals here yet',
  // search
  'search.title': 'Search for deals',
  'search.subtitle': 'Find the best delivery deals for your shipments',
  'search.local': 'Local',
  'search.international': 'International',
  'search.forTrip': 'Search for Trip',
  'search.forDelivery': 'Search for Delivery Request',
  'search.weight': 'Weight',
  // chat
  'chat.inbox': 'Inbox',
  'chat.message': 'Message...',
  'chat.empty': 'No conversations yet',
};

const _fr = <String, String>{
  'nav.home': 'Accueil',
  'nav.deals': 'Offres',
  'nav.chat': 'Discussion',
  'nav.profile': 'Profil',
  'welcome.tagline': 'Expédiez partout, en toute simplicité',
  'welcome.subtitle':
      'Connectez-vous avec des voyageurs sur votre trajet et envoyez vos colis localement ou dans le monde entier.',
  'welcome.login': 'Connexion',
  'welcome.createAccount': 'Créer un compte',
  'welcome.guest': 'Continuer en tant qu’invité',
  'auth.welcomeBack': 'Bon retour',
  'auth.loginSubtitle': 'Connectez-vous pour continuer à expédier et voyager.',
  'auth.email': 'E-mail',
  'auth.password': 'Mot de passe',
  'auth.forgotPassword': 'Mot de passe oublié ?',
  'auth.noAccount': 'Pas encore de compte ? ',
  'auth.signUp': 'S’inscrire',
  'auth.haveAccount': 'Vous avez déjà un compte ? ',
  'auth.signIn': 'Se connecter',
  'auth.createAccount': 'Créer un compte',
  'common.save': 'Enregistrer',
  'common.cancel': 'Annuler',
  'common.retry': 'Réessayer',
  'common.close': 'Fermer',
  'common.continue': 'Continuer',
  'common.confirm': 'Confirmer',
  'common.delete': 'Supprimer',
  'common.edit': 'Modifier',
  'common.search': 'Rechercher',
  'common.language': 'Langue',
  'deals.title': 'Offres',
  'deals.filter': 'Filtrer les offres',
  'deals.all': 'Toutes',
  'deals.empty': 'Aucune offre pour le moment',
  'search.title': 'Rechercher des offres',
  'search.subtitle': 'Trouvez les meilleures offres de livraison pour vos envois',
  'search.local': 'Local',
  'search.international': 'International',
  'search.forTrip': 'Rechercher un voyage',
  'search.forDelivery': 'Rechercher une demande de livraison',
  'search.weight': 'Poids',
  'chat.inbox': 'Messages',
  'chat.message': 'Message...',
  'chat.empty': 'Aucune conversation pour le moment',
};
