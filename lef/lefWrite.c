/*
 * lefWrite.c --      
 *
 * This module incorporates the LEF/DEF format for standard-cell place and
 * route.
 *
 * Version 0.1 (May 1, 2003):  LEF output for cells, to include pointer to
 * GDS, automatic generation of GDS if not already made, bounding box export,
 * port export, export of irouter "fence", "magnet", and "rotate" layers    
 * for defining router hints, and generating areas for obstructions and
 * pin layers.
 *
 */

#ifndef lint
static char rcsid[] __attribute__ ((unused)) = "$Header: /usr/cvsroot/magic-8.0/lef/lefWrite.c,v 1.3 2010/06/24 12:37:18 tim Exp $";            
#endif  /* not lint */

#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <errno.h>

#include "tcltk/tclmagic.h"
#include "utils/magic.h"
#include "utils/geometry.h"
#include "tiles/tile.h"
#include "utils/hash.h"
#include "database/database.h"
#include "utils/tech.h"
#include "utils/utils.h"
#include "utils/malloc.h"
#include "utils/stack.h"
#include "utils/signals.h"
#include "windows/windows.h"
#include "dbwind/dbwind.h"
#include "graphics/graphics.h"
#include "utils/main.h"
#include "utils/undo.h"
#include "cif/cif.h"
#include "lef/lefInt.h"

/* ---------------------------------------------------------------------*/

/* Stack of cell definitions */
Stack *lefDefStack;

/*
 * ---------------------------------------------------------------------
 *
 * lefFileOpen --
 *
 * Open the .lef file corresponding to a .mag file.
 * If def->cd_file is non-NULL, the .lef file is just def->cd_file with
 * the trailing .mag replaced by .lef.  Otherwise, the .lef file is just
 * def->cd_name followed by .lef.
 *
 * Results:
 *	Return a pointer to an open FILE, or NULL if the .lef
 *	file could not be opened in the specified mode.
 *
 * Side effects:
 *	Opens a file.
 *
 * ----------------------------------------------------------------------------
 */

FILE *
lefFileOpen(def, file, suffix, mode, prealfile)
    CellDef *def;	/* Cell whose .lef file is to be written.  Should
			 * be NULL if file is being opened for reading.
			 */
    char *file;		/* If non-NULL, open 'name'.lef; otherwise,
			 * derive filename from 'def' as described
			 * above.
			 */
    char *suffix;	/* Either ".lef" for LEF files or ".def" for DEF files */
    char *mode;		/* Either "r" or "w", the mode in which the LEF/DEF
			 * file is to be opened.
			 */
    char **prealfile;	/* If this is non-NULL, it gets set to point to
			 * a string holding the name of the LEF/DEF file.
			 */
{
    char namebuf[512], *name, *endp, *ends;
    int len;
    FILE *rfile;

    if (file) 
	name = file;
    else if (def && def->cd_file)
	name = def->cd_file;
    else if (def)
	name = def->cd_name;
    else
    {
	TxError("LEF file open:  No file name or cell given\n");
	return NULL;
    }

    // Strip off suffix, if there is one

    ends = strrchr(name, '/');
    if (ends == NULL)
	ends = name;
    else
	ends++;

    if (endp = strrchr(ends, '.'))
    {
	if (!strcmp(endp, suffix))
	{
	    len = endp - name;
	    if (len > sizeof namebuf - 1) len = sizeof namebuf - 1;
	    (void) strncpy(namebuf, name, len);
	    namebuf[len] = '\0';
	    name = namebuf;
	}
    }

    /* Try once as-is, and if this fails, try stripping any leading	*/
    /* path information in case cell is in a read-only directory (mode	*/
    /* "read" only, and if def is non-NULL).				*/

    if ((rfile = PaOpen(name, mode, suffix, Path, CellLibPath, prealfile)) != NULL)
	return rfile;

    if (def) 
    {
	if (name == def->cd_name) return NULL;
	name = def->cd_name;
	return (PaOpen(name, mode, suffix, Path, CellLibPath, prealfile));
    }
    else
	return NULL;
}


/*
 * ----------------------------------------------------------------------------
 *
 * lefWriteHeader --
 *
 * This routine generates LEF header output for a cell or cell hierarchy.
 * Although the LEF/DEF spec does not define a "header" per se, this is
 * considered to be all LEF output not including the MACRO calls.  The
 * header, therefore, defines layers, process routing rules, units
 * (lambda), and so forth.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Writes output to the open file "f".
 *
 * ----------------------------------------------------------------------------
 */

void
lefWriteHeader(def, f, lefTech)
    CellDef *def;	/* Def for which to generate LEF output */
    FILE *f;		/* Output to this file */
    bool lefTech;	/* If TRUE, write layer information */
{
    TileType type;

    TxPrintf("Diagnostic:  Write LEF header for cell %s\n", def->cd_name);

    /* NOTE:  This routine corresponds to Envisia LEF/DEF Language	*/
    /* Reference version 5.3 (May 31, 2000)				*/

    fprintf(f, "VERSION 5.3 ;\n");
    fprintf(f, "   NAMESCASESENSITIVE ON ;\n");
    fprintf(f, "   NOWIREEXTENSIONATPIN ON ;\n");
    fprintf(f, "   DIVIDERCHAR \"/\" ;\n");
    fprintf(f, "   BUSBITCHARS \"[]\" ;\n");

    /* As I understand it, this refers to the scalefactor of the GDS	*/
    /* file output.  Magic does all GDS in nanometers, so the LEF	*/
    /* scalefactor (conversion to microns) is always 1000.		*/

    fprintf(f, "UNITS\n");
    fprintf(f, "   DATABASE MICRONS 1000 ;\n");
    fprintf(f, "END UNITS\n");
    fprintf(f, "\n");

    if (!lefTech) return;

    UndoDisable();

    /* Layers (minimal information) */

    if (LefInfo.ht_table != (HashEntry **)NULL)
    {
	HashSearch hs;
	HashEntry *he;
	lefLayer *lefl;

	float oscale = CIFGetOutputScale(1000);	/* lambda->micron conversion */

	HashStartSearch(&hs);
	while (he = HashNext(&LefInfo, &hs))
	{
	    lefl = (lefLayer *)HashGetValue(he);
	    if (!lefl) continue;

	    if (lefl->refCnt > 0)
	    {
		/* Avoid writing more than one entry per defined layer */
	        if (lefl->refCnt > 1) lefl->refCnt = -lefl->refCnt;

		/* Ignore obstruction-only layers */
		if (lefl->type == -1) continue;	

		/* Ignore VIA types, report only CUT types here */
		else if ((lefl->lefClass == CLASS_VIA)
			&& lefl->info.via.cell != NULL) continue;

		/* Ignore boundary types */
		else if (lefl->lefClass == CLASS_BOUND) continue;

		fprintf(f, "LAYER %s\n", lefl->canonName);
		if (lefl->lefClass == CLASS_VIA)
		{
		    int cutarea;
		    cutarea = (lefl->info.via.area.r_xtop - lefl->info.via.area.r_xbot);
		    cutarea *= (lefl->info.via.area.r_ytop - lefl->info.via.area.r_ybot);
		    fprintf(f, "   TYPE CUT ;\n");
		    if (cutarea > 0)
			fprintf(f, "   CUT AREA %f ;\n",
					(float)cutarea * oscale * oscale);
		}
		else if (lefl->lefClass == CLASS_ROUTE)
		{
		    fprintf(f, "   TYPE ROUTING ;\n");
		    if (lefl->info.route.pitch > 0)
			fprintf(f, "   PITCH %f ;\n", (float)(lefl->info.route.pitch)
				* oscale);
		    if (lefl->info.route.width > 0)
			fprintf(f, "   WIDTH %f ;\n", (float)(lefl->info.route.width)
				* oscale);
		    if (lefl->info.route.spacing > 0)
			fprintf(f, "   SPACING %f ;\n", (float)(lefl->info.route.spacing)
				* oscale);
		    /* No sense in providing direction info unless we know the width */
		    if (lefl->info.route.width > 0)
			fprintf(f, "   DIRECTION %s ;\n", (lefl->info.route.hdirection)
				?  "HORIZONTAL" : "VERTICAL");
		}
		else if (lefl->lefClass == CLASS_MASTER)
		{
		    fprintf(f, "   TYPE MASTERSLICE ;\n");
		}
		else if (lefl->lefClass == CLASS_OVERLAP)
		{
		    fprintf(f, "   TYPE OVERLAP ;\n");
		}
		fprintf(f, "END %s\n\n", lefl->canonName);
	    }
	}

	/* Return reference counts to normal */
	HashStartSearch(&hs);
	while (he = HashNext(&LefInfo, &hs))
	{
	    lefl = (lefLayer *)HashGetValue(he);
	    if (lefl && lefl->refCnt < 0)
		lefl->refCnt = -lefl->refCnt;
	}
    }

    /* Vias (to be completed, presumably) */
    /* Rules (to be completed, presumably) */

    UndoEnable();
}

#define LEF_MODE_PORT		0
#define LEF_MODE_OBSTRUCT	1

typedef struct
{
    FILE	*file;		/* file to write to */
    TileType	lastType;	/* last type output, so we minimize LAYER
				 * statements.
				 */
    CellDef	*lefFlat;	/* Soure CellDef (flattened cell) */
    CellDef	*lefYank;	/* CellDef to write into */
    LefMapping  *lefMagicMap;	/* Layer inverse mapping table */
    TileTypeBitMask rmask;	/* mask of routing layer types */
    Point	origin;		/* origin of cell */
    float	oscale;		/* units scale conversion factor */
    int		pNum;		/* Plane number for tile marking */
    int		numWrites;	/* Track number of writes to output */
    int		lefMode;	/* can be LEF_MODE_PORT when searching
				 * connections into ports, or
				 * LEF_MODE_OBSTRUCT when generating
				 * obstruction geometry.  LEF polyons
				 * must be manhattan, so if we find a
				 * split tile, LEF_MODE_PORT ignores it,
				 * and LEF_MODE_OBSTRUCT outputs the
				 * whole tile.
				 */
} lefClient;

/*
 * ----------------------------------------------------------------------------
 *
 */

int
lefEraseGeometry(tile, cdata)
    Tile *tile;
    ClientData cdata;
{
    lefClient *lefdata = (lefClient *)cdata;
    CellDef *flatDef = lefdata->lefFlat;
    Rect area;
    TileType ttype, otype;

    TiToRect(tile, &area);

    otype = TiGetTypeExact(tile);
    if (IsSplit(tile))
        ttype = (otype & TT_SIDE) ? SplitRightType(tile) :
                        SplitLeftType(tile);
    else
        ttype = otype;

    /* Erase the tile area out of lefFlat */
    DBErase(flatDef, &area, ttype);

    return 0;
}

/*
 * ----------------------------------------------------------------------------
 *
 * Callback function to find the cell boundary based on the specified
 * boundary layer type.  Typically this will be a single rectangle on
 * its own plane, but for completeness, all geometry in the cell is
 * checked, and the bounding rectangle adjusted to fit that area.
 *
 * Return 0 to keep the search going.
 * ----------------------------------------------------------------------------
 */

int
lefGetBound(tile, cdata)
    Tile *tile;
    ClientData cdata;
{
    Rect *boundary = (Rect *)cdata;
    Rect area;

    TiToRect(tile, &area);
    GeoInclude(&area, boundary);
    return 0;
}

/*
 * ----------------------------------------------------------------------------
 *
 * lefYankGeometry --
 *
 * Function called from SimSrConnect() that copies geometry from
 * the cell into a yank buffer cell, one pin connection at a time.
 *
 * Return 0 to keep the search going.
 * ----------------------------------------------------------------------------
 */

int
lefYankGeometry(tile, cdata)
    Tile *tile;
    ClientData cdata;
{
    lefClient *lefdata = (lefClient *)cdata;
    Rect area;
    TileType ttype, otype, ptype;
    LefMapping *lefMagicToLefLayer;
    TileTypeBitMask sMask;
    bool iscut;

    /* Ignore marked tiles */
    if (tile->ti_client != (ClientData)CLIENTDEFAULT) return 0;

    otype = TiGetTypeExact(tile);
    if (IsSplit(tile))
	ttype = (otype & TT_SIDE) ? SplitRightType(tile) :
			SplitLeftType(tile);
    else
	ttype = otype;

    /* Output geometry only for defined routing layers	*/
    /* If we have encountered a contact type, then	*/
    /* decompose into constituent layers and see if any	*/
    /* of them are in the route layer masks.		*/

    if (DBIsContact(ttype))
    {
	DBFullResidueMask(ttype, &sMask);

	/* Use the first routing layer that is represented	*/
	/* in sMask.  If none, then return.			*/

	for (ttype = TT_TECHDEPBASE; ttype < DBNumTypes; ttype++)
	    if (TTMaskHasType(&sMask, ttype))
		if (TTMaskHasType(&lefdata->rmask, ttype))
		    break;

	if (ttype == DBNumTypes) return 0;
	iscut = TRUE;
    }
    else
    {
	if (!TTMaskHasType(&lefdata->rmask, ttype)) return 0;
	iscut = FALSE;
    }

    TiToRect(tile, &area);

    while (ttype < DBNumTypes)
    {
	lefMagicToLefLayer = lefdata->lefMagicMap;
	if (lefMagicToLefLayer[ttype].lefInfo != NULL)
	{
	    if (IsSplit(tile))
		// Set only the side being yanked
		ptype = (otype & (TT_DIAGONAL | TT_SIDE | TT_DIRECTION)) |
			((otype & TT_SIDE) ? (ttype << 14) : ttype);
	    else
		ptype = ttype;

	    /* Paint into yank buffer */
	    DBNMPaintPlane(lefdata->lefYank->cd_planes[lefdata->pNum],
			ptype, &area, DBStdPaintTbl(ttype, lefdata->pNum),
			(PaintUndoInfo *)NULL);
	}

	if (iscut == FALSE) break;

	for (++ttype; ttype < DBNumTypes; ttype++)
	    if (TTMaskHasType(&sMask, ttype))
		if (TTMaskHasType(&lefdata->rmask, ttype))
		    break;
    }
    return 0;
}

/*
 * ----------------------------------------------------------------------------
 *
 * lefWriteGeometry --
 *
 * Function called from SimSrConnect() that outputs a RECT
 * record for each tile called.  Note that LEF does not define
 * nonmanhattan geometry (see above, comments in lefClient typedef).
 *
 * Return 0 to keep the search going.
 * ----------------------------------------------------------------------------
 */

int
lefWriteGeometry(tile, cdata)
    Tile *tile;
    ClientData cdata;
{
    lefClient *lefdata = (lefClient *)cdata;
    FILE *f = lefdata->file;
    float scale = lefdata->oscale;
    TileType ttype, otype = TiGetTypeExact(tile);
    LefMapping *lefMagicToLefLayer = lefdata->lefMagicMap;

    /* Ignore tiles that have already been output */
    if (tile->ti_client != (ClientData)CLIENTDEFAULT)
	return 0;

    /* Mark this tile as visited */
    TiSetClient(tile, (ClientData)1);

    /* Get layer type */
    if (IsSplit(tile))
	ttype = (otype & TT_SIDE) ? SplitRightType(tile) :
			SplitLeftType(tile);
    else
	ttype = otype;

    /* Only LEF routing layer types will be in the yank buffer */

    if (!TTMaskHasType(&lefdata->rmask, ttype)) return 0;

    if (lefdata->numWrites == 0)
    {
	if (lefdata->lefMode == LEF_MODE_PORT)
	    fprintf(f, "      PORT\n");
	else
	    fprintf(f, "   OBS\n");
    }
    lefdata->numWrites++;

    if (ttype != lefdata->lastType)
	if (lefMagicToLefLayer[ttype].lefInfo != NULL)
	{
	    fprintf(f, "         LAYER %s ;\n",
				lefMagicToLefLayer[ttype].lefName);
	    lefdata->lastType = ttype;
	}

    if (IsSplit(tile))
	if (otype & TT_SIDE)
	{
	    if (otype & TT_DIRECTION)
		fprintf(f, "	    POLYGON %.4f %.4f %.4f %.4f %.4f %.4f ;\n",
			scale * (float)(LEFT(tile) - lefdata->origin.p_x),
			scale * (float)(TOP(tile) - lefdata->origin.p_y),
			scale * (float)(RIGHT(tile) - lefdata->origin.p_x),
			scale * (float)(TOP(tile) - lefdata->origin.p_y),
			scale * (float)(RIGHT(tile) - lefdata->origin.p_x),
			scale * (float)(BOTTOM(tile) - lefdata->origin.p_y));
	    else
		fprintf(f, "	    POLYGON %.4f %.4f %.4f %.4f %.4f %.4f ;\n",
			scale * (float)(RIGHT(tile) - lefdata->origin.p_x),
			scale * (float)(TOP(tile) - lefdata->origin.p_y),
			scale * (float)(RIGHT(tile) - lefdata->origin.p_x),
			scale * (float)(BOTTOM(tile) - lefdata->origin.p_y),
			scale * (float)(LEFT(tile) - lefdata->origin.p_x),
			scale * (float)(BOTTOM(tile) - lefdata->origin.p_y));
	}
	else
	{
	    if (otype & TT_DIRECTION)
		fprintf(f, "	    POLYGON %.4f %.4f %.4f %.4f %.4f %.4f ;\n",
			scale * (float)(LEFT(tile) - lefdata->origin.p_x),
			scale * (float)(TOP(tile) - lefdata->origin.p_y),
			scale * (float)(RIGHT(tile) - lefdata->origin.p_x),
			scale * (float)(BOTTOM(tile) - lefdata->origin.p_y),
			scale * (float)(LEFT(tile) - lefdata->origin.p_x),
			scale * (float)(BOTTOM(tile) - lefdata->origin.p_y));
	    else
		fprintf(f, "	    POLYGON %.4f %.4f %.4f %.4f %.4f %.4f ;\n",
			scale * (float)(LEFT(tile) - lefdata->origin.p_x),
			scale * (float)(TOP(tile) - lefdata->origin.p_y),
			scale * (float)(RIGHT(tile) - lefdata->origin.p_x),
			scale * (float)(TOP(tile) - lefdata->origin.p_y),
			scale * (float)(LEFT(tile) - lefdata->origin.p_x),
			scale * (float)(BOTTOM(tile) - lefdata->origin.p_y));
	}
    else
	fprintf(f, "	    RECT %.4f %.4f %.4f %.4f ;\n",
		scale * (float)(LEFT(tile) - lefdata->origin.p_x),
		scale * (float)(BOTTOM(tile) - lefdata->origin.p_y),
		scale * (float)(RIGHT(tile) - lefdata->origin.p_x),
		scale * (float)(TOP(tile) - lefdata->origin.p_y));

    return 0;
}

/*
 * ----------------------------------------------------------------------------
 *
 * MakeLegalLEFSyntax --
 *
 *	Follow syntactical rules of the LEF spec.  Most notably, Magic
 *	node names often contain the hash mark '#', which is illegal
 *	in LEF output.  Other illegal LEF characters are space, newline,
 *	semicolon, and for literal names: dash, asterisk, and percent.
 *	All of the above will be replaced with underscores if found.
 *
 * Results:
 *	Returns an allocated string containing the modified result, or
 *	else returns the original string pointer.  It is the responsibility
 *	of the calling function to free the result if it is not equal to
 *	the argument.
 *
 * Side effects:
 *	Allocated memory.
 *
 * ----------------------------------------------------------------------------
 */

char *
MakeLegalLEFSyntax(text)
    char *text;
{
    static char *badLEFchars = ";# -*$\n";
    char *cptr, *bptr;
    char *rstr;

    for (cptr = text; *cptr != '\0'; cptr++)
	for (bptr = badLEFchars; *bptr != '\0'; bptr++)
	    if (*cptr == *bptr) break;

    if (*cptr == '\0' && *bptr == '\0')
	return text;

    rstr = StrDup((char **)NULL, text); 
    
    for (cptr = rstr; *cptr != '\0'; cptr++)
	for (bptr = badLEFchars; bptr != '\0'; bptr++)
	    if (*cptr == *bptr) 
	    {
		*cptr = '_';
		break;
	    }

    return rstr;
}
	    
/*
 * ----------------------------------------------------------------------------
 *
 * lefWriteMacro --
 *
 * This routine generates LEF output for a cell in the form of a LEF
 * "MACRO" block.  Includes information on cell dimensions, pins,
 * ports (physical layout associated with pins), and routing obstructions.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Writes output to the open file "f".
 *
 * ----------------------------------------------------------------------------
 */

void
lefWriteMacro(def, f, scale)
    CellDef *def;	/* Def for which to generate LEF output */
    FILE *f;		/* Output to this file */
    float scale;	/* Output distance units conversion factor */
{
    bool propfound;
    char *propvalue, *class = NULL;
    Label *lab;
    Rect boundary, labr;
    SearchContext scx;
    CellDef *lefFlatDef;
    CellUse lefFlatUse, lefSourceUse;
    TileTypeBitMask lmask, boundmask, *lrmask;
    TileType ttype;
    lefClient lc;
    int idx, pNum, maxport, curport;
    char *LEFtext;
    HashSearch hs;
    HashEntry *he;

    extern CellDef *SelectDef;

    UndoDisable();

    TxPrintf("Diagnostic:  Writing LEF output for cell %s\n", def->cd_name);

    lefFlatDef = DBCellLookDef("__lefFlat__");
    if (lefFlatDef == (CellDef *)NULL)
	lefFlatDef = DBCellNewDef("__lefFlat__", (char *)NULL);
    DBCellSetAvail(lefFlatDef);
    lefFlatDef->cd_flags |= CDINTERNAL;

    lefFlatUse.cu_id = StrDup((char **)NULL, "Flattened cell");
    lefFlatUse.cu_expandMask = CU_DESCEND_SPECIAL;
    lefFlatUse.cu_def = lefFlatDef;
    DBSetTrans(&lefFlatUse, &GeoIdentityTransform);
    
    lefSourceUse.cu_id = StrDup((char **)NULL, "Source cell");
    lefSourceUse.cu_expandMask = CU_DESCEND_ALL;
    lefSourceUse.cu_def = def;
    DBSetTrans(&lefSourceUse, &GeoIdentityTransform);

    scx.scx_use = &lefSourceUse;
    scx.scx_trans = GeoIdentityTransform;
    scx.scx_area = def->cd_bbox;
    DBCellCopyAllPaint(&scx, &DBAllButSpaceAndDRCBits, CU_DESCEND_ALL, &lefFlatUse);

    /* Reset scx to point to the flattened use */
    scx.scx_use = &lefFlatUse;

    /* Set up client record. */

    lc.file = f;
    lc.oscale = scale;
    lc.lefMagicMap = defMakeInverseLayerMap();
    lc.lastType = TT_SPACE;
    lc.lefFlat = lefFlatDef;

    TxPrintf("Diagnostic:  Scale value is %f\n", lc.oscale);

    /* Which layers are routing layers are defined in the tech file.	*/

    TTMaskZero(&lc.rmask);
    TTMaskZero(&boundmask);

    /* Any layer which has a port label attached to it should by	*/
    /* necessity be considered a routing layer.	 Usually this will not	*/
    /* add anything to the mask already created.			*/

    for (lab = def->cd_labels; lab != NULL; lab = lab->lab_next)
	if (lab->lab_flags & PORT_DIR_MASK)
	    TTMaskSetType(&lc.rmask, lab->lab_type);

    HashStartSearch(&hs);
    while (he = HashNext(&LefInfo, &hs))
    {
	lefLayer *lefl = (lefLayer *)HashGetValue(he);
	if (lefl && (lefl->lefClass == CLASS_ROUTE || lefl->lefClass == CLASS_VIA))
	    if (lefl->type != -1)
	    {
		TTMaskSetType(&lc.rmask, lefl->type);
		if (DBIsContact(lefl->type))
		{
		    lrmask = DBResidueMask(lefl->type);
		    TTMaskSetMask(&lc.rmask, lrmask);
		}
	    }
	    if (lefl->obsType != -1)
		TTMaskSetType(&lc.rmask, lefl->obsType);

	if (lefl && (lefl->lefClass == CLASS_BOUND))
	    if (lefl->type != -1)
		TTMaskSetType(&boundmask, lefl->type);
    }

    /* NOTE:  This routine corresponds to Envisia LEF/DEF Language	*/
    /* Reference version 5.3 (May 31, 2000)				*/

    /* Macro header information (to be completed) */

    fprintf(f, "MACRO %s\n", def->cd_name); 

    /* LEF data is stored in the "cd_props" hash table.  If the hash	*/
    /* table is NULL or a specific property undefined, then the LEF	*/
    /* value takes the default.  Generally, LEF properties which have	*/
    /* default values are optional, so in this case we will leave those	*/
    /* entries blank.							*/

    propvalue = (char *)DBPropGet(def, "LEFclass", &propfound);
    if (propfound)
    {
	fprintf(f, "   CLASS %s\n", propvalue);
	class = propvalue;
    }
    else
    {
	/* Needs a class of some kind.  Use BLOCK as default if not defined */
	fprintf(f, "   CLASS BLOCK\n");
    }

    propvalue = (char *)DBPropGet(def, "LEFsource", &propfound);
    if (propfound)
	fprintf(f, "   SOURCE %s\n", propvalue);

    fprintf(f, "   FOREIGN %s ;\n", def->cd_name);

    /* If a boundary class was declared in the LEF section, then use	*/
    /* that layer type to define the boundary.  Otherwise, the cell	*/
    /* boundary is defined by the magic database.  If the boundary	*/
    /* class is used, and the boundary layer corner is not on the	*/
    /* origin, then shift all geometry by the difference.		*/

    if (!TTMaskIsZero(&boundmask))
    {
	for (pNum = PL_PAINTBASE; pNum < DBNumPlanes; pNum++)
	    DBSrPaintArea((Tile *)NULL, def->cd_planes[pNum], 
			&TiPlaneRect, &boundmask, lefGetBound,
			(ClientData)(&boundary));
    }
    else
	boundary = def->cd_bbox;

    /* Write position and size information */

    fprintf(f, "   ORIGIN %.4f %.4f ;\n",
		-lc.oscale * (float)boundary.r_xbot,
		-lc.oscale * (float)boundary.r_ybot);

    fprintf(f, "   SIZE %.4f BY %.4f ;\n",
		lc.oscale * (float)(boundary.r_xtop - boundary.r_xbot),
		lc.oscale * (float)(boundary.r_ytop - boundary.r_ybot));

    lc.origin.p_x = 0;
    lc.origin.p_y = 0;

    propvalue = (char *)DBPropGet(def, "LEFsymmetry", &propfound);
    if (propfound)
	fprintf(f, "   SYMMETRY %s\n", propvalue);

    /* Generate cell for yanking obstructions */

    lc.lefYank = DBCellLookDef("__lefYank__");
    if (lc.lefYank == (CellDef *)NULL)
    lc.lefYank = DBCellNewDef("__lefYank__", (char *)NULL);

    DBCellSetAvail(lc.lefYank);
    lc.lefYank->cd_flags |= CDINTERNAL;

    /* List of pins (ports) (to be refined?) */

    lc.lefMode = LEF_MODE_PORT;

    /* Determine the maximum port number, then output ports in order */
    maxport = -1;
    curport = 0;
    for (lab = def->cd_labels; lab != NULL; lab = lab->lab_next)
	if (lab->lab_flags & PORT_DIR_MASK)
	{
	    curport++;
	    idx = lab->lab_flags & PORT_NUM_MASK;
	    if (idx > maxport)
		maxport = idx;
	}

    if (maxport < 0) lab = def->cd_labels;

    /* Work through pins in port order, if defined, otherwise	*/
    /* in order of the label list.				*/

    for (idx = 0; idx < ((maxport < 0) ? curport : maxport + 1); idx++)
    {
	if (maxport >= 0)
	{
	    for (lab = def->cd_labels; lab != NULL; lab = lab->lab_next)
		if (lab->lab_flags & PORT_DIR_MASK)
		    if (!(lab->lab_flags & PORT_VISITED))
			if ((lab->lab_flags & PORT_NUM_MASK) == idx)
			    break;
	}
	else
	    while (lab && !(lab->lab_flags & PORT_DIR_MASK)) lab = lab->lab_next;

	if (lab == NULL) continue;	/* Happens if indexes are skipped */

	/* Ignore ports which we have already visited (shouldn't happen	*/
	/* unless ports are shorted together).				*/

	if (lab->lab_flags & PORT_VISITED) continue;

	fprintf(f, "   PIN %s\n", lab->lab_text);
	if (lab->lab_flags & PORT_CLASS_MASK)
	{
	    fprintf(f, "      DIRECTION ");
	    switch(lab->lab_flags & PORT_CLASS_MASK)
	    {
		case PORT_CLASS_INPUT:
		    fprintf(f, "INPUT");
		    break;
		case PORT_CLASS_OUTPUT:
		    fprintf(f, "OUTPUT");
		    break;
		case PORT_CLASS_TRISTATE:
		    fprintf(f, "OUTPUT TRISTATE");
		    break;
		case PORT_CLASS_BIDIRECTIONAL:
		    fprintf(f, "INOUT");
		    break;
		case PORT_CLASS_FEEDTHROUGH:
		    fprintf(f, "FEEDTHRU");
		    break;
	    }
	    fprintf(f, " ;\n");
	}
	if (lab->lab_flags & PORT_USE_MASK)
	{
	    fprintf(f, "      USE ");
	    switch(lab->lab_flags & PORT_USE_MASK)
	    {
		case PORT_USE_SIGNAL:
		    fprintf(f, "SIGNAL");
		    break;
		case PORT_USE_ANALOG:
		    fprintf(f, "ANALOG");
		    break;
		case PORT_USE_POWER:
		    fprintf(f, "POWER");
		    break;
		case PORT_USE_GROUND:
		    fprintf(f, "GROUND");
		    break;
		case PORT_USE_CLOCK:
		    fprintf(f, "CLOCK");
		    break;
	    }
	    fprintf(f, " ;\n");
	}

	/* Query pin geometry for SHAPE (to be done?) */

	/* Generate port layout geometry using SimSrConnect()		*/
	/* Selects all electrically-connected material into the		*/
	/* select def.  Output all the layers and geometries of		*/
	/* the select def.						*/
	/*								*/
	/* We use SimSrConnect() and not DBSrConnect() because		*/
	/* SimSrConnect() leaves "marks" (tile->ti_client = 1)		*/
	/* which allows us to later search through all tiles for	*/
	/* anything that is not connected to a port, and generate	*/
	/* an "obstruction" record for it.				*/
	/*								*/
	/* Note: Use DBIsContact() to check if the layer is a VIA.	*/
	/* Presently, I am treating contacts like any other layer.	*/

	labr = lab->lab_rect;

	/* Deal with degenerate (line or point) labels	*/
	/* by growing by 1 in each direction.		*/

	if (labr.r_xtop - labr.r_xbot == 0)
	{
	    labr.r_xtop++;
	    labr.r_xbot--;
	}
	if (labr.r_ytop - labr.r_ybot == 0)
	{
	    labr.r_ytop++;
	    labr.r_ybot--;
	}

	// Avoid errors caused by labels not attached to anything.
	TTMaskClearType(&lc.rmask, TT_SPACE);

	// TTMaskSetOnlyType(&lmask, lab->lab_type);

	ttype = TT_SPACE;
	scx.scx_area = labr;
	SelectClear();
	SelectNet(&scx, lab->lab_type, 0, NULL, FALSE);

	// For all geometry in the selection, write LEF records,
	// and mark the corresponding tiles in lefFlatDef as
	// visited.

	lc.numWrites = 0;
	lc.lastType = TT_SPACE;
	for (pNum = PL_PAINTBASE; pNum < DBNumPlanes; pNum++)
	{
	    lc.pNum = pNum;
	    DBSrPaintArea((Tile *)NULL, SelectDef->cd_planes[pNum], 
			&TiPlaneRect, &DBAllButSpaceAndDRCBits,
			lefYankGeometry, (ClientData) &lc);

	    DBSrPaintArea((Tile *)NULL, lc.lefYank->cd_planes[pNum], 
	    		&TiPlaneRect, &lc.rmask,
	    		lefWriteGeometry, (ClientData) &lc);

	    DBSrPaintArea((Tile *)NULL, SelectDef->cd_planes[pNum], 
			&TiPlaneRect, &DBAllButSpaceAndDRCBits,
			lefEraseGeometry, (ClientData) &lc);
	}
	DBCellClearDef(lc.lefYank);

	if (lc.numWrites > 0)
	    fprintf(f, "      END\n");	/* end of port geometries */
	lab->lab_flags |= PORT_VISITED;

	LEFtext = MakeLegalLEFSyntax(lab->lab_text);
	fprintf(f, "   END %s\n", lab->lab_text);	/* end of pin */
	if (LEFtext != lab->lab_text) freeMagic(LEFtext);

	if (maxport >= 0)
	{
	    /* Sanity check to see if port number is a duplicate */
	    for (lab = lab->lab_next; lab != NULL; lab = lab->lab_next)
	    {
		if (lab->lab_flags & PORT_DIR_MASK)
		    if ((lab->lab_flags & PORT_NUM_MASK) == idx)
		    {
			TxError("Port index %d is used more than once\n", idx);
			idx--;
		    }
	    }
	}
	else
	    lab = lab->lab_next;
    }

    /* Clear all PORT_VISITED bits in labels */
    for (lab = def->cd_labels; lab != NULL; lab = lab->lab_next)
	if (lab->lab_flags & PORT_DIR_MASK)
	    lab->lab_flags &= ~(PORT_VISITED);

    /* List of routing obstructions */

    lc.lefMode = LEF_MODE_OBSTRUCT;
    lc.numWrites = 0;
    lc.lastType = TT_SPACE;

    /* Restrict to routing planes only */

    for (pNum = PL_PAINTBASE; pNum < DBNumPlanes; pNum++)
    {
	lc.pNum = pNum;
	DBSrPaintArea((Tile *)NULL, lefFlatDef->cd_planes[pNum], 
		&TiPlaneRect, &DBAllButSpaceAndDRCBits,
		lefYankGeometry, (ClientData) &lc);

	DBSrPaintArea((Tile *)NULL, lc.lefYank->cd_planes[pNum], 
		&TiPlaneRect, &lc.rmask,
		lefWriteGeometry, (ClientData) &lc);
    }

    if (lc.numWrites > 0)
	fprintf(f, "   END\n");	/* end of obstruction geometries */

    fprintf(f, "END %s\n", def->cd_name);	/* end of macro */

    SigDisableInterrupts();
    freeMagic(lc.lefMagicMap);
    DBCellClearDef(lc.lefYank);
    DBCellClearDef(lefFlatDef);
    freeMagic(lefSourceUse.cu_id);
    freeMagic(lefFlatUse.cu_id);
    SelectClear();
    SigEnableInterrupts();

    UndoEnable();
}

/*
 *------------------------------------------------------------
 *
 * LefWriteAll --
 *
 *	Write LEF-format output for each cell, beginning with
 *	the top-level cell use "rootUse".
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Writes a .lef file to disk.
 *
 *------------------------------------------------------------
 */

void
LefWriteAll(rootUse, writeTopCell, lefTech)
    CellUse *rootUse;
    bool writeTopCell;
    bool lefTech;
{
    CellDef *def, *rootdef;
    FILE *f;
    char *filename;
    float scale = CIFGetOutputScale(1000);	/* conversion to microns */

    rootdef = rootUse->cu_def;

    /* Make sure the entire subtree is read in */
    DBCellReadArea(rootUse, &rootdef->cd_bbox);

    /* Fix up bounding boxes if they've changed */
    DBFixMismatch();

    /* Mark all defs as being unvisited */
    (void) DBCellSrDefs(0, lefDefInitFunc, (ClientData) 0);

    /* Recursively visit all defs in the tree and push on stack */
    lefDefStack = StackNew(100);
    (void) lefDefPushFunc(rootUse);

    /* Open the file for output */

    f = lefFileOpen(rootdef, (char *)NULL, ".lef", "w", &filename);

    TxPrintf("Generating LEF output %s for hierarchy rooted at cell %s:\n",
		filename, rootdef->cd_name);

    if (f == NULL)
    {
#ifdef MAGIC_WRAPPER
	TxError("Cannot open output file %s (%s).\n", filename,
		strerror(errno));
#else
	TxError("Cannot open output file: ");
	perror(filename);
#endif
	return;
    }

    /* Now generate LEF output for all the cells we just found */

    lefWriteHeader(rootdef, f, lefTech);

    while (def = (CellDef *) StackPop(lefDefStack))
    {
	def->cd_client = (ClientData) 0;
	if (!SigInterruptPending)
	    if ((writeTopCell == TRUE) || (def != rootdef))
		lefWriteMacro(def, f, scale);
    }

    /* End the LEF file */
    fprintf(f, "END LIBRARY ;\n");

    fclose(f);
    StackFree(lefDefStack);
}
 
/*
 * Function to initialize the client data field of all
 * cell defs, in preparation for generating LEF output
 * for a subtree rooted at a particular def.
 */

int 
lefDefInitFunc(def)
    CellDef *def;
{
    def->cd_client = (ClientData) 0;
    return (0);
}

/*
 * Function to push each cell def on lefDefStack
 * if it hasn't already been pushed, and then recurse
 * on all that def's children.
 */

int
lefDefPushFunc(use)
    CellUse *use;
{
    CellDef *def = use->cu_def;

    if (def->cd_client || (def->cd_flags & CDINTERNAL))
	return (0);

    def->cd_client = (ClientData) 1;
    StackPush((ClientData) def, lefDefStack);
    (void) DBCellEnum(def, lefDefPushFunc, (ClientData) 0);
    return (0);
}

/*
 *------------------------------------------------------------
 *
 * LefWriteCell --
 *
 *	Write LEF-format output for the indicated cell.
 *
 * Results:
 *	None.
 *
 * Side effects:
 *	Writes a single .lef file to disk.
 *
 *------------------------------------------------------------
 */

void
LefWriteCell(def, outName, isRoot, lefTech)
    CellDef *def;		/* Cell being written */
    char *outName;		/* Name of output file, or NULL. */
    bool isRoot;		/* Is this the root cell? */
    bool lefTech;		/* Output layer information if TRUE */
{
    char *filename;
    FILE *f;
    float scale = CIFGetOutputScale(1000);

    f = lefFileOpen(def, outName, ".lef", "w", &filename);

    TxPrintf("Generating LEF output %s for cell %s:\n", filename, def->cd_name);

    if (f == NULL)
    {
#ifdef MAGIC_WRAPPER
	TxError("Cannot open output file %s (%s).\n", filename,
		strerror(errno));
#else
	TxError("Cannot open output file: ");
	perror(filename);
#endif
	return;
    }

    if (isRoot)
	lefWriteHeader(def, f, lefTech);
    lefWriteMacro(def, f, scale);
    fclose(f);
}

