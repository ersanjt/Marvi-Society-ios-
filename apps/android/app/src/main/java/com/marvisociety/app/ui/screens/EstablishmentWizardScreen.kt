package com.marvisociety.app.ui.screens

import android.net.Uri
import androidx.activity.compose.rememberLauncherForActivityResult
import androidx.activity.result.PickVisualMediaRequest
import androidx.activity.result.contract.ActivityResultContracts
import androidx.compose.foundation.background
import androidx.compose.foundation.border
import androidx.compose.foundation.clickable
import androidx.compose.foundation.horizontalScroll
import androidx.compose.foundation.layout.Arrangement
import androidx.compose.foundation.layout.Column
import androidx.compose.foundation.layout.Row
import androidx.compose.foundation.layout.Spacer
import androidx.compose.foundation.layout.fillMaxSize
import androidx.compose.foundation.layout.fillMaxWidth
import androidx.compose.foundation.layout.height
import androidx.compose.foundation.layout.padding
import androidx.compose.foundation.layout.size
import androidx.compose.foundation.rememberScrollState
import androidx.compose.foundation.shape.RoundedCornerShape
import androidx.compose.foundation.verticalScroll
import androidx.compose.material3.Button
import androidx.compose.material3.ButtonDefaults
import androidx.compose.material3.Checkbox
import androidx.compose.material3.CheckboxDefaults
import androidx.compose.material3.FilterChip
import androidx.compose.material3.FilterChipDefaults
import androidx.compose.material3.MaterialTheme
import androidx.compose.material3.OutlinedButton
import androidx.compose.material3.OutlinedTextField
import androidx.compose.material3.OutlinedTextFieldDefaults
import androidx.compose.material3.Text
import androidx.compose.material3.TextButton
import androidx.compose.runtime.Composable
import androidx.compose.runtime.LaunchedEffect
import androidx.compose.runtime.getValue
import androidx.compose.runtime.mutableStateListOf
import androidx.compose.runtime.mutableStateOf
import androidx.compose.runtime.remember
import androidx.compose.runtime.setValue
import androidx.compose.ui.Alignment
import androidx.compose.ui.Modifier
import androidx.compose.ui.draw.clip
import androidx.compose.ui.layout.ContentScale
import androidx.compose.ui.text.font.FontWeight
import androidx.compose.ui.unit.dp
import coil.compose.AsyncImage
import com.marvisociety.app.data.BrandSummary
import com.marvisociety.app.data.BusinessCategoryCatalog
import com.marvisociety.app.data.OfferCategory
import com.marvisociety.app.l10n.MarviL10n
import com.marvisociety.app.ui.components.MarviCard
import com.marvisociety.app.ui.components.MarviScreen
import com.marvisociety.app.ui.theme.MarviColor
import com.marvisociety.app.ui.viewmodel.AppViewModel

private enum class WizardStep { BRAND, HUB, DETAILS, ADDRESS, PHOTOS }

private val EstablishmentCategoryOptions = BusinessCategoryCatalog.all.map { it.english }

@Composable
fun EstablishmentWizardScreen(
    viewModel: AppViewModel,
    onBack: () -> Unit,
    onSubmitted: () -> Unit
) {
    var step by remember { mutableStateOf(WizardStep.BRAND) }
    var localError by remember { mutableStateOf<String?>(null) }

    var organizationName by remember { mutableStateOf("") }
    var brandName by remember { mutableStateOf("") }
    var selectedBrand by remember { mutableStateOf<BrandSummary?>(null) }
    var creatingNewBrand by remember { mutableStateOf(false) }

    var establishmentName by remember { mutableStateOf("") }
    var venueId by remember { mutableStateOf<String?>(null) }

    var detailsComplete by remember { mutableStateOf(false) }
    var addressComplete by remember { mutableStateOf(false) }
    var photosComplete by remember { mutableStateOf(false) }

    var instagram by remember { mutableStateOf("") }
    var description by remember { mutableStateOf("") }
    val selectedCategories = remember { mutableStateListOf<String>() }
    var customCategory by remember { mutableStateOf("") }
    var contactName by remember { mutableStateOf(viewModel.profile.name) }
    var contactPhone by remember { mutableStateOf("") }
    var contactIsSelf by remember { mutableStateOf(false) }

    var isPhysical by remember { mutableStateOf(true) }
    var country by remember { mutableStateOf("Türkiye") }
    var city by remember { mutableStateOf("Istanbul") }
    var locationLabel by remember { mutableStateOf("") }
    var addressLine1 by remember { mutableStateOf("") }
    var addressLine2 by remember { mutableStateOf("") }
    var postalCode by remember { mutableStateOf("") }
    var latText by remember { mutableStateOf("41.0082") }
    var lngText by remember { mutableStateOf("28.9784") }

    var logoUri by remember { mutableStateOf<Uri?>(null) }
    val galleryUris = remember { mutableStateListOf<Uri>() }

    LaunchedEffect(Unit) {
        viewModel.loadMyBrands()
    }

    LaunchedEffect(viewModel.myBrands) {
        if (viewModel.myBrands.isEmpty()) {
            creatingNewBrand = true
        } else if (selectedBrand == null && !creatingNewBrand) {
            selectedBrand = viewModel.myBrands.first()
        }
    }

    val logoPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickVisualMedia()
    ) { uri -> logoUri = uri }

    val galleryPicker = rememberLauncherForActivityResult(
        contract = ActivityResultContracts.PickMultipleVisualMedia(maxItems = 8)
    ) { uris ->
        galleryUris.clear()
        galleryUris.addAll(uris.take(8))
    }

    val busy = viewModel.isEstablishmentBusy
    val canSubmit = detailsComplete && addressComplete && photosComplete && venueId != null

    MarviScreen {
        Column(
            modifier = Modifier
                .fillMaxSize()
                .verticalScroll(rememberScrollState())
                .padding(16.dp),
            verticalArrangement = Arrangement.spacedBy(12.dp)
        ) {
            Row(
                modifier = Modifier.fillMaxWidth(),
                horizontalArrangement = Arrangement.SpaceBetween,
                verticalAlignment = Alignment.CenterVertically
            ) {
                TextButton(onClick = {
                    when (step) {
                        WizardStep.BRAND -> onBack()
                        WizardStep.HUB -> onBack()
                        WizardStep.DETAILS, WizardStep.ADDRESS, WizardStep.PHOTOS -> {
                            step = WizardStep.HUB
                            localError = null
                        }
                    }
                }) {
                    Text(viewModel.t(MarviL10n.Key.BACK), color = MarviColor.Muted)
                }
                Text(
                    viewModel.t(MarviL10n.Key.EST_WIZARD_TITLE),
                    fontWeight = FontWeight.Bold,
                    color = MarviColor.Ink,
                    style = MaterialTheme.typography.titleMedium
                )
                Spacer(modifier = Modifier.size(48.dp))
            }

            localError?.let { Text(it, color = MarviColor.Tomato) }
            viewModel.lastSyncError?.takeIf { localError == null }?.let {
                Text(it, color = MarviColor.Tomato)
            }

            when (step) {
                WizardStep.BRAND -> BrandStep(
                    viewModel = viewModel,
                    organizationName = organizationName,
                    brandName = brandName,
                    establishmentName = establishmentName,
                    brands = viewModel.myBrands,
                    selectedBrand = selectedBrand,
                    creatingNewBrand = creatingNewBrand || viewModel.myBrands.isEmpty(),
                    busy = busy,
                    onOrganizationName = { organizationName = it },
                    onBrandName = { brandName = it },
                    onEstablishmentName = { establishmentName = it },
                    onSelectBrand = {
                        selectedBrand = it
                        creatingNewBrand = false
                    },
                    onCreateNewBrand = {
                        creatingNewBrand = true
                        selectedBrand = null
                    },
                    onContinue = {
                        localError = null
                        val name = establishmentName.trim()
                        if (name.isEmpty()) {
                            localError = viewModel.t(MarviL10n.Key.EST_NAME_REQUIRED)
                            return@BrandStep
                        }
                        if (creatingNewBrand || viewModel.myBrands.isEmpty()) {
                            if (organizationName.isBlank() || brandName.isBlank()) {
                                localError = viewModel.t(MarviL10n.Key.EST_ORG_BRAND_REQUIRED)
                                return@BrandStep
                            }
                            viewModel.createOrganizationWithBrand(organizationName, brandName) { brand ->
                                if (brand == null) return@createOrganizationWithBrand
                                selectedBrand = brand
                                viewModel.createEstablishmentDraft(brand.brandId, name) { id ->
                                    if (id == null) return@createEstablishmentDraft
                                    venueId = id
                                    step = WizardStep.HUB
                                }
                            }
                        } else {
                            val brand = selectedBrand
                            if (brand == null) {
                                localError = viewModel.t(MarviL10n.Key.EST_SELECT_BRAND)
                                return@BrandStep
                            }
                            viewModel.createEstablishmentDraft(brand.brandId, name) { id ->
                                if (id == null) return@createEstablishmentDraft
                                venueId = id
                                step = WizardStep.HUB
                            }
                        }
                    }
                )

                WizardStep.HUB -> HubStep(
                    viewModel = viewModel,
                    establishmentName = establishmentName,
                    brandLabel = selectedBrand?.let { "${it.organizationName} · ${it.brandName}" }.orEmpty(),
                    detailsComplete = detailsComplete,
                    addressComplete = addressComplete,
                    photosComplete = photosComplete,
                    canSubmit = canSubmit,
                    busy = busy,
                    onOpenDetails = { step = WizardStep.DETAILS },
                    onOpenAddress = { step = WizardStep.ADDRESS },
                    onOpenPhotos = { step = WizardStep.PHOTOS },
                    onSubmit = {
                        val id = venueId ?: return@HubStep
                        localError = null
                        if (!canSubmit) {
                            localError = viewModel.t(MarviL10n.Key.EST_COMPLETE_ALL)
                            return@HubStep
                        }
                        viewModel.submitEstablishmentForReview(id) { ok ->
                            if (ok) onSubmitted()
                        }
                    }
                )

                WizardStep.DETAILS -> DetailsStep(
                    viewModel = viewModel,
                    instagram = instagram,
                    description = description,
                    selectedCategories = selectedCategories,
                    customCategory = customCategory,
                    contactName = contactName,
                    contactPhone = contactPhone,
                    contactIsSelf = contactIsSelf,
                    busy = busy,
                    onInstagram = { instagram = it },
                    onDescription = { if (it.length <= 200) description = it },
                    onToggleCategory = { label ->
                        if (selectedCategories.contains(label)) selectedCategories.remove(label)
                        else selectedCategories.add(label)
                    },
                    onCustomCategory = { customCategory = it },
                    onAddCustomCategory = {
                        val value = customCategory.trim()
                        if (value.length >= 2 && !selectedCategories.contains(value)) {
                            selectedCategories.add(value)
                            customCategory = ""
                        }
                    },
                    onContactName = { contactName = it },
                    onContactPhone = { contactPhone = it },
                    onContactIsSelf = { checked ->
                        contactIsSelf = checked
                        if (checked) contactName = viewModel.profile.name
                    },
                    onSave = {
                        localError = null
                        val id = venueId
                        if (id == null) {
                            localError = viewModel.t(MarviL10n.Key.SYNC_ERROR)
                            return@DetailsStep
                        }
                        val normalizedInstagram = instagram.trim().removePrefix("@")
                        if (normalizedInstagram.isNotEmpty() && normalizedInstagram.length < 2) {
                            localError = viewModel.t(MarviL10n.Key.EST_IG_REQUIRED)
                            return@DetailsStep
                        }
                        if (description.isBlank()) {
                            localError = viewModel.t(MarviL10n.Key.EST_DESC_REQUIRED)
                            return@DetailsStep
                        }
                        if (selectedCategories.isEmpty()) {
                            localError = viewModel.t(MarviL10n.Key.EST_CATEGORY_REQUIRED)
                            return@DetailsStep
                        }
                        if (contactName.isBlank() || contactPhone.isBlank()) {
                            localError = viewModel.t(MarviL10n.Key.EST_CONTACT_REQUIRED)
                            return@DetailsStep
                        }
                        viewModel.saveEstablishmentDetails(
                            venueId = id,
                            instagramHandle = instagram,
                            description = description,
                            categories = selectedCategories.toList(),
                            contactName = contactName,
                            contactPhone = contactPhone,
                            contactIsSelf = contactIsSelf,
                            offerCategory = mapOfferCategory(selectedCategories.first())
                        ) { ok ->
                            if (ok) {
                                detailsComplete = true
                                step = WizardStep.HUB
                            }
                        }
                    }
                )

                WizardStep.ADDRESS -> AddressStep(
                    viewModel = viewModel,
                    isPhysical = isPhysical,
                    country = country,
                    city = city,
                    locationLabel = locationLabel,
                    addressLine1 = addressLine1,
                    addressLine2 = addressLine2,
                    postalCode = postalCode,
                    latText = latText,
                    lngText = lngText,
                    busy = busy,
                    onIsPhysical = { isPhysical = it },
                    onCountry = { country = it },
                    onCity = { city = it },
                    onLocationLabel = { locationLabel = it },
                    onAddressLine1 = { addressLine1 = it },
                    onAddressLine2 = { addressLine2 = it },
                    onPostalCode = { postalCode = it },
                    onLat = { latText = it.filter { ch -> ch.isDigit() || ch == '.' || ch == '-' } },
                    onLng = { lngText = it.filter { ch -> ch.isDigit() || ch == '.' || ch == '-' } },
                    onSave = {
                        localError = null
                        val id = venueId
                        if (id == null) {
                            localError = viewModel.t(MarviL10n.Key.SYNC_ERROR)
                            return@AddressStep
                        }
                        if (country.isBlank() || city.isBlank()) {
                            localError = viewModel.t(MarviL10n.Key.EST_CITY_COUNTRY_REQUIRED)
                            return@AddressStep
                        }
                        val lat = latText.toDoubleOrNull()
                        val lng = lngText.toDoubleOrNull()
                        if (isPhysical) {
                            if (addressLine1.isBlank()) {
                                localError = viewModel.t(MarviL10n.Key.EST_ADDRESS_REQUIRED)
                                return@AddressStep
                            }
                            if (lat == null || lng == null) {
                                localError = viewModel.t(MarviL10n.Key.EST_MAP_REQUIRED)
                                return@AddressStep
                            }
                        }
                        viewModel.saveEstablishmentAddress(
                            venueId = id,
                            isPhysical = isPhysical,
                            country = country,
                            city = city,
                            locationLabel = locationLabel.ifBlank { city },
                            addressLine1 = addressLine1,
                            addressLine2 = addressLine2,
                            postalCode = postalCode,
                            lat = if (isPhysical) lat else null,
                            lng = if (isPhysical) lng else null
                        ) { ok ->
                            if (ok) {
                                addressComplete = true
                                step = WizardStep.HUB
                            }
                        }
                    }
                )

                WizardStep.PHOTOS -> PhotosStep(
                    viewModel = viewModel,
                    logoUri = logoUri,
                    galleryUris = galleryUris,
                    busy = busy,
                    onPickLogo = {
                        logoPicker.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                        )
                    },
                    onPickGallery = {
                        galleryPicker.launch(
                            PickVisualMediaRequest(ActivityResultContracts.PickVisualMedia.ImageOnly)
                        )
                    },
                    onSave = {
                        localError = null
                        val id = venueId
                        val logo = logoUri
                        if (id == null) {
                            localError = viewModel.t(MarviL10n.Key.SYNC_ERROR)
                            return@PhotosStep
                        }
                        if (logo == null) {
                            localError = viewModel.t(MarviL10n.Key.EST_LOGO_REQUIRED)
                            return@PhotosStep
                        }
                        if (galleryUris.size < 3) {
                            localError = viewModel.t(MarviL10n.Key.EST_PHOTOS_MIN)
                            return@PhotosStep
                        }
                        viewModel.saveEstablishmentPhotos(id, logo, galleryUris.toList()) { ok ->
                            if (ok) {
                                photosComplete = true
                                step = WizardStep.HUB
                            }
                        }
                    }
                )
            }
        }
    }
}

@Composable
private fun BrandStep(
    viewModel: AppViewModel,
    organizationName: String,
    brandName: String,
    establishmentName: String,
    brands: List<BrandSummary>,
    selectedBrand: BrandSummary?,
    creatingNewBrand: Boolean,
    busy: Boolean,
    onOrganizationName: (String) -> Unit,
    onBrandName: (String) -> Unit,
    onEstablishmentName: (String) -> Unit,
    onSelectBrand: (BrandSummary) -> Unit,
    onCreateNewBrand: () -> Unit,
    onContinue: () -> Unit
) {
    Text(
        viewModel.t(MarviL10n.Key.EST_BRAND_STEP_TITLE),
        style = MaterialTheme.typography.headlineSmall,
        color = MarviColor.Ink,
        fontWeight = FontWeight.Bold
    )
    Text(viewModel.t(MarviL10n.Key.EST_BRAND_STEP_SUB), color = MarviColor.Muted)

    if (brands.isNotEmpty()) {
        MarviCard {
            Text(viewModel.t(MarviL10n.Key.EST_YOUR_BRANDS), fontWeight = FontWeight.SemiBold, color = MarviColor.Ink)
            brands.forEach { brand ->
                val selected = !creatingNewBrand && selectedBrand?.brandId == brand.brandId
                Row(
                    modifier = Modifier
                        .fillMaxWidth()
                        .clip(RoundedCornerShape(12.dp))
                        .background(if (selected) MarviColor.Rose.copy(alpha = 0.15f) else MarviColor.PanelElevated)
                        .border(1.dp, if (selected) MarviColor.Rose else MarviColor.Border, RoundedCornerShape(12.dp))
                        .clickable { onSelectBrand(brand) }
                        .padding(12.dp),
                    horizontalArrangement = Arrangement.SpaceBetween
                ) {
                    Column {
                        Text(brand.brandName, fontWeight = FontWeight.Bold, color = MarviColor.Ink)
                        Text(brand.organizationName, color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
                    }
                }
            }
            OutlinedButton(onClick = onCreateNewBrand, modifier = Modifier.fillMaxWidth()) {
                Text(viewModel.t(MarviL10n.Key.EST_CREATE_NEW_BRAND))
            }
        }
    }

    if (creatingNewBrand || brands.isEmpty()) {
        MarviCard {
            WizardField(organizationName, onOrganizationName, viewModel.t(MarviL10n.Key.EST_ORG_NAME))
            WizardField(brandName, onBrandName, viewModel.t(MarviL10n.Key.EST_BRAND_NAME))
        }
    }

    MarviCard {
        WizardField(establishmentName, onEstablishmentName, viewModel.t(MarviL10n.Key.EST_NAME))
    }

    WizardPrimaryButton(
        title = if (busy) viewModel.t(MarviL10n.Key.LOADING) else viewModel.t(MarviL10n.Key.CONTINUE),
        enabled = !busy,
        onClick = onContinue
    )
}

@Composable
private fun HubStep(
    viewModel: AppViewModel,
    establishmentName: String,
    brandLabel: String,
    detailsComplete: Boolean,
    addressComplete: Boolean,
    photosComplete: Boolean,
    canSubmit: Boolean,
    busy: Boolean,
    onOpenDetails: () -> Unit,
    onOpenAddress: () -> Unit,
    onOpenPhotos: () -> Unit,
    onSubmit: () -> Unit
) {
    Text(
        establishmentName.ifBlank { viewModel.t(MarviL10n.Key.EST_WIZARD_TITLE) },
        style = MaterialTheme.typography.headlineSmall,
        color = MarviColor.Ink,
        fontWeight = FontWeight.Bold
    )
    if (brandLabel.isNotBlank()) {
        Text(brandLabel, color = MarviColor.Muted)
    }
    Text(viewModel.t(MarviL10n.Key.EST_HUB_SUB), color = MarviColor.Graphite)

    ChecklistRow(
        title = viewModel.t(MarviL10n.Key.EST_CHECKLIST_DETAILS),
        complete = detailsComplete,
        onClick = onOpenDetails
    )
    ChecklistRow(
        title = viewModel.t(MarviL10n.Key.EST_CHECKLIST_ADDRESS),
        complete = addressComplete,
        onClick = onOpenAddress
    )
    ChecklistRow(
        title = viewModel.t(MarviL10n.Key.EST_CHECKLIST_PHOTOS),
        complete = photosComplete,
        onClick = onOpenPhotos
    )

    WizardPrimaryButton(
        title = if (busy) viewModel.t(MarviL10n.Key.LOADING) else viewModel.t(MarviL10n.Key.EST_SUBMIT_REVIEW),
        enabled = !busy && canSubmit,
        onClick = onSubmit
    )
    if (!canSubmit) {
        Text(viewModel.t(MarviL10n.Key.EST_COMPLETE_ALL), color = MarviColor.Muted, style = MaterialTheme.typography.bodySmall)
    }
}

@Composable
private fun ChecklistRow(title: String, complete: Boolean, onClick: () -> Unit) {
    MarviCard(modifier = Modifier.clickable(onClick = onClick)) {
        Row(
            modifier = Modifier.fillMaxWidth(),
            horizontalArrangement = Arrangement.SpaceBetween,
            verticalAlignment = Alignment.CenterVertically
        ) {
            Text(title, fontWeight = FontWeight.SemiBold, color = MarviColor.Ink)
            Text(
                if (complete) "✓" else "→",
                color = if (complete) MarviColor.Emerald else MarviColor.Rose,
                fontWeight = FontWeight.Bold
            )
        }
    }
}

@Composable
private fun DetailsStep(
    viewModel: AppViewModel,
    instagram: String,
    description: String,
    selectedCategories: List<String>,
    customCategory: String,
    contactName: String,
    contactPhone: String,
    contactIsSelf: Boolean,
    busy: Boolean,
    onInstagram: (String) -> Unit,
    onDescription: (String) -> Unit,
    onToggleCategory: (String) -> Unit,
    onCustomCategory: (String) -> Unit,
    onAddCustomCategory: () -> Unit,
    onContactName: (String) -> Unit,
    onContactPhone: (String) -> Unit,
    onContactIsSelf: (Boolean) -> Unit,
    onSave: () -> Unit
) {
    Text(
        viewModel.t(MarviL10n.Key.EST_CHECKLIST_DETAILS),
        style = MaterialTheme.typography.headlineSmall,
        color = MarviColor.Ink,
        fontWeight = FontWeight.Bold
    )
    MarviCard {
        WizardField(instagram, onInstagram, viewModel.t(MarviL10n.Key.INSTAGRAM_PLACEHOLDER))
        OutlinedTextField(
            value = description,
            onValueChange = onDescription,
            label = { Text(viewModel.t(MarviL10n.Key.EST_DESCRIPTION)) },
            supportingText = { Text("${description.length}/200", color = MarviColor.Muted) },
            modifier = Modifier.fillMaxWidth(),
            minLines = 3,
            colors = wizardFieldColors()
        )
        Text(viewModel.t(MarviL10n.Key.EST_CATEGORIES), fontWeight = FontWeight.SemiBold, color = MarviColor.Ink)
        Row(
            modifier = Modifier.horizontalScroll(rememberScrollState()),
            horizontalArrangement = Arrangement.spacedBy(8.dp)
        ) {
            EstablishmentCategoryOptions.forEach { label ->
                FilterChip(
                    selected = selectedCategories.contains(label),
                    onClick = { onToggleCategory(label) },
                    label = { Text(label) },
                    colors = FilterChipDefaults.filterChipColors(
                        selectedContainerColor = MarviColor.Rose.copy(alpha = 0.25f),
                        selectedLabelColor = MarviColor.Rose
                    )
                )
            }
        }
        WizardField(
            customCategory,
            onCustomCategory,
            if (viewModel.preferredLanguage == com.marvisociety.app.data.AppLanguage.TURKISH) {
                "Kategori yoksa buraya yazın"
            } else {
                "Can't find it? Add your category"
            }
        )
        OutlinedButton(
            onClick = onAddCustomCategory,
            enabled = customCategory.trim().length >= 2,
            modifier = Modifier.fillMaxWidth()
        ) {
            Text(if (viewModel.preferredLanguage == com.marvisociety.app.data.AppLanguage.TURKISH) "Kategori ekle" else "Add category")
        }
        WizardField(contactName, onContactName, viewModel.t(MarviL10n.Key.EST_CONTACT_NAME))
        WizardField(contactPhone, onContactPhone, viewModel.t(MarviL10n.Key.EST_CONTACT_PHONE))
        Row(
            verticalAlignment = Alignment.CenterVertically,
            modifier = Modifier
                .fillMaxWidth()
                .clickable { onContactIsSelf(!contactIsSelf) }
        ) {
            Checkbox(
                checked = contactIsSelf,
                onCheckedChange = onContactIsSelf,
                colors = CheckboxDefaults.colors(checkedColor = MarviColor.Rose)
            )
            Text(viewModel.t(MarviL10n.Key.EST_CONTACT_IS_SELF), color = MarviColor.Ink)
        }
    }
    WizardPrimaryButton(
        title = if (busy) viewModel.t(MarviL10n.Key.SAVING) else viewModel.t(MarviL10n.Key.CONTINUE),
        enabled = !busy,
        onClick = onSave
    )
}

@Composable
private fun AddressStep(
    viewModel: AppViewModel,
    isPhysical: Boolean,
    country: String,
    city: String,
    locationLabel: String,
    addressLine1: String,
    addressLine2: String,
    postalCode: String,
    latText: String,
    lngText: String,
    busy: Boolean,
    onIsPhysical: (Boolean) -> Unit,
    onCountry: (String) -> Unit,
    onCity: (String) -> Unit,
    onLocationLabel: (String) -> Unit,
    onAddressLine1: (String) -> Unit,
    onAddressLine2: (String) -> Unit,
    onPostalCode: (String) -> Unit,
    onLat: (String) -> Unit,
    onLng: (String) -> Unit,
    onSave: () -> Unit
) {
    Text(
        viewModel.t(MarviL10n.Key.EST_CHECKLIST_ADDRESS),
        style = MaterialTheme.typography.headlineSmall,
        color = MarviColor.Ink,
        fontWeight = FontWeight.Bold
    )
    Row(horizontalArrangement = Arrangement.spacedBy(8.dp)) {
        FilterChip(
            selected = isPhysical,
            onClick = { onIsPhysical(true) },
            label = { Text(viewModel.t(MarviL10n.Key.EST_PHYSICAL)) },
            colors = FilterChipDefaults.filterChipColors(
                selectedContainerColor = MarviColor.Rose.copy(alpha = 0.25f),
                selectedLabelColor = MarviColor.Rose
            )
        )
        FilterChip(
            selected = !isPhysical,
            onClick = { onIsPhysical(false) },
            label = { Text(viewModel.t(MarviL10n.Key.EST_ONLINE)) },
            colors = FilterChipDefaults.filterChipColors(
                selectedContainerColor = MarviColor.Rose.copy(alpha = 0.25f),
                selectedLabelColor = MarviColor.Rose
            )
        )
    }
    MarviCard {
        WizardField(country, onCountry, viewModel.t(MarviL10n.Key.EST_COUNTRY))
        WizardField(city, onCity, viewModel.t(MarviL10n.Key.EST_CITY))
        WizardField(locationLabel, onLocationLabel, viewModel.t(MarviL10n.Key.EST_LOCATION_LABEL))
        if (isPhysical) {
            WizardField(addressLine1, onAddressLine1, viewModel.t(MarviL10n.Key.EST_ADDRESS_LINE1))
            WizardField(addressLine2, onAddressLine2, viewModel.t(MarviL10n.Key.EST_ADDRESS_LINE2))
            WizardField(postalCode, onPostalCode, viewModel.t(MarviL10n.Key.EST_POSTAL_CODE))
            WizardField(latText, onLat, viewModel.t(MarviL10n.Key.EST_LATITUDE))
            WizardField(lngText, onLng, viewModel.t(MarviL10n.Key.EST_LONGITUDE))
        }
    }
    WizardPrimaryButton(
        title = if (busy) viewModel.t(MarviL10n.Key.SAVING) else viewModel.t(MarviL10n.Key.CONTINUE),
        enabled = !busy,
        onClick = onSave
    )
}

@Composable
private fun PhotosStep(
    viewModel: AppViewModel,
    logoUri: Uri?,
    galleryUris: List<Uri>,
    busy: Boolean,
    onPickLogo: () -> Unit,
    onPickGallery: () -> Unit,
    onSave: () -> Unit
) {
    Text(
        viewModel.t(MarviL10n.Key.EST_CHECKLIST_PHOTOS),
        style = MaterialTheme.typography.headlineSmall,
        color = MarviColor.Ink,
        fontWeight = FontWeight.Bold
    )
    Text(viewModel.t(MarviL10n.Key.EST_PHOTOS_SUB), color = MarviColor.Muted)
    MarviCard {
        OutlinedButton(onClick = onPickLogo, modifier = Modifier.fillMaxWidth()) {
            Text(
                if (logoUri != null) viewModel.t(MarviL10n.Key.EST_LOGO_ADDED)
                else viewModel.t(MarviL10n.Key.EST_ADD_LOGO)
            )
        }
        if (logoUri != null) {
            AsyncImage(
                model = logoUri,
                contentDescription = null,
                modifier = Modifier
                    .fillMaxWidth()
                    .height(120.dp)
                    .clip(RoundedCornerShape(12.dp)),
                contentScale = ContentScale.Crop
            )
        }
        OutlinedButton(onClick = onPickGallery, modifier = Modifier.fillMaxWidth()) {
            Text(
                viewModel.t(MarviL10n.Key.EST_ADD_GALLERY).replace("%d", galleryUris.size.toString())
            )
        }
        if (galleryUris.isNotEmpty()) {
            Row(
                modifier = Modifier.horizontalScroll(rememberScrollState()),
                horizontalArrangement = Arrangement.spacedBy(8.dp)
            ) {
                galleryUris.forEach { uri ->
                    AsyncImage(
                        model = uri,
                        contentDescription = null,
                        modifier = Modifier
                            .size(88.dp)
                            .clip(RoundedCornerShape(10.dp)),
                        contentScale = ContentScale.Crop
                    )
                }
            }
        }
    }
    WizardPrimaryButton(
        title = if (busy) viewModel.t(MarviL10n.Key.SAVING) else viewModel.t(MarviL10n.Key.CONTINUE),
        enabled = !busy,
        onClick = onSave
    )
}

@Composable
private fun WizardField(value: String, onValueChange: (String) -> Unit, label: String) {
    OutlinedTextField(
        value = value,
        onValueChange = onValueChange,
        label = { Text(label) },
        modifier = Modifier.fillMaxWidth(),
        singleLine = true,
        colors = wizardFieldColors()
    )
}

@Composable
private fun wizardFieldColors() = OutlinedTextFieldDefaults.colors(
    focusedBorderColor = MarviColor.Rose,
    unfocusedBorderColor = MarviColor.Border,
    focusedTextColor = MarviColor.Ink,
    unfocusedTextColor = MarviColor.Ink,
    focusedLabelColor = MarviColor.Muted,
    unfocusedLabelColor = MarviColor.Muted,
    cursorColor = MarviColor.Rose,
    focusedSupportingTextColor = MarviColor.Muted,
    unfocusedSupportingTextColor = MarviColor.Muted
)

@Composable
private fun WizardPrimaryButton(title: String, enabled: Boolean, onClick: () -> Unit) {
    Button(
        onClick = onClick,
        enabled = enabled,
        modifier = Modifier.fillMaxWidth(),
        colors = ButtonDefaults.buttonColors(
            containerColor = MarviColor.Rose,
            disabledContainerColor = MarviColor.Muted.copy(alpha = 0.3f)
        ),
        shape = RoundedCornerShape(14.dp)
    ) {
        Text(title, fontWeight = FontWeight.Bold, modifier = Modifier.padding(vertical = 6.dp))
    }
}

private fun mapOfferCategory(label: String): OfferCategory {
    return BusinessCategoryCatalog.offerCategoryFor(label)
}
